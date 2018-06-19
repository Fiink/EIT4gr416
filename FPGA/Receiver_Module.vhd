--------------------------------------------------
-- RECEIVE:
--		x"FFD9" is used to determine when all data has been received
--
--		States:
--			rx_idle: Wait until the FPGA has received a byte of data
--			rx_move_b: Move received byte to CRC_input buffer
--			rx_CRC: Initiate CRC check on the Decoder component. Wait until CRC_ready is high.
--					If CRC_pass is low (0), raise the errorPin. In either case, the program will continue.
--			rx_move_r: Move CRC_output to RAM
--			rx_check: Check for end-of-image identifier. If found, start transmission.
--
-- TRANSMIT:
--		max_ram_addr is used to determine when all data has been sent
--
--		States:
--			tx_init: Set certain variables. This state is only active once.
--			tx_move_r: Copy data from RAM to the output buffer (tx_buffer)
--					If all data has been transmitted, the program will go to the tx_end state
--			tx_send: Wait until no data is currently being sent. If tx_busy = 0, send signal that new message should be sent.
--			tx_delay: ~10 clk-cycle delay, ensures tx_buffer isn't being altered while the uart component is latching onto the data.
--			tx_end: Empty state, indicates transmission is completed.
--
--	NOTE:
--		This code uses built-in block memory instead of the external SRAM, as we had several issues writing to/reading from the chip. 
--		This means the total amount of memory available for the image is ~ 5 KB. 

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Receiver_Module is
    Port (
		CLK     : IN STD_LOGIC;
		led	  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
		input   : IN STD_LOGIC;
		output  : OUT STD_LOGIC;
		errorPin : OUT STD_LOGIC := '0'
	);
end Receiver_Module;

architecture Behavioral of Receiver_Module is
	COMPONENT uart	-- Instantiation of the UART component
	PORT(
		clk : IN std_logic;
		reset_n : IN std_logic;
		tx_ena : IN std_logic;
		tx_data : IN std_logic_vector(7 downto 0);
		rx : IN std_logic;          
		rx_busy : OUT std_logic;
		rx_error : OUT std_logic;
		rx_data : OUT std_logic_vector(7 downto 0);
		tx_busy : OUT std_logic;
		tx : OUT std_logic
		);
	END COMPONENT;
	
	-- UART component signals
	-- TRANSMIT
	signal reset_n			: STD_LOGIC := '1';
	signal tx_ena			: STD_LOGIC := '0';
	signal tx_busy			: STD_LOGIC	:= '0';
	signal tx_buffer	: STD_LOGIC_VECTOR(7 downto 0) := x"00";
	-- RECEIVE
	signal rx_busy			: STD_LOGIC;
	signal rx_error		: STD_LOGIC;
	signal rx_buffer	: STD_LOGIC_VECTOR(7 downto 0) := x"00";
	SIGNAL fsm : STD_LOGIC_VECTOR(3 downto 0) := x"0";
	
	
	COMPONENT CRC_Decoder
	PORT(
		CLK : IN std_logic;
		input : IN std_logic_vector(31 downto 0);
		ResetPin : IN std_logic;          
		output : OUT std_logic_vector(15 downto 0);
		CRCpass : OUT std_logic;
		ready : OUT std_logic
		);
	END COMPONENT;
	
	--CRC_Decoder component signals
	SIGNAL CRC_input : STD_LOGIC_VECTOR(31 downto 0) := (OTHERS => '0');
	SIGNAL CRC_output : STD_LOGIC_VECTOR(15 downto 0) := (OTHERS => '0');
	SIGNAL CRC_reset : STD_LOGIC := '0';
	SIGNAL CRC_pass  : STD_LOGIC := '0';
	SIGNAL CRC_ready : STD_LOGIC := '0'; 
	
	--Internal memory
	TYPE ram_s IS ARRAY (0 TO 9999/2) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ram : ram_s := (OTHERS => (OTHERS => '0'));
	ATTRIBUTE ram_style : STRING;
	ATTRIBUTE ram_style OF ram : SIGNAL IS "distributed";
	SIGNAL ram_addr : UNSIGNED(13 DOWNTO 0) := (OTHERS => '0');
	
	--FSM flags
	TYPE machine IS (rx_idle, rx_move_b, rx_CRC, rx_move_r, rx_check, tx_init, tx_move_r, tx_send, tx_delay, tx_end);	--state machine data type
	SIGNAL state :	machine;									--receive state machine
	SIGNAL f_error : BOOLEAN := FALSE;
	SIGNAL f_busy_trigger : BOOLEAN := FALSE;
	SIGNAL f_firstMove : BOOLEAN := TRUE;
	SIGNAL f_tx_move : BOOLEAN := FALSE;
	
	--Counters
	SIGNAL bytes_received : INTEGER RANGE 0 TO 3 := 0;
	SIGNAL CRC_state : INTEGER RANGE 0 TO 3 := 0;
	SIGNAL save_state : INTEGER RANGE 0 TO 2 := 0;
	SIGNAL cntr_move_r : INTEGER RANGE 0 TO 1 := 0;
	SIGNAL max_ram_addr : UNSIGNED(13 DOWNTO 0) := (OTHERS => '0');
	SIGNAL cntr_delay : INTEGER RANGE 0 TO 9 := 0;
	
	--Signal busses
	SIGNAL check_buffer : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
	
begin
	Inst_uart: uart PORT MAP(
		clk 		=> clk,				--system clock
		reset_n 	=> reset_n,			--asynchronous active low reset
		tx_ena 	=> tx_ena,			--initiate transmission	(H = Initiate new transmission, L = Do nothing)
		tx_data 	=> tx_buffer,		--data to transmit
		rx 		=> input,			--receive pin
		rx_busy 	=> rx_busy,			--data reception in progress
		rx_error	=> rx_error,		--start, parity, or stop bit error detected	(H: start/parity/stop bit error, L: No error detected)
		rx_data 	=> rx_buffer,		--data received
		tx_busy 	=> tx_busy,			--transmission in progress (H = Busy, L = Reception complete, rx_data & rx_error available)
		tx 		=> output			--transmit pin
	);
	
	Inst_CRC_Decoder: CRC_Decoder PORT MAP(
		CLK => CLK,						--system clock
		input => CRC_input,			--32-bit bus input (2 data bytes, 2 CRC bytes)
		output => CRC_output,		--16-bit bus output (2 data bytes). If a correctable error was detected, it has been corrected on the output.
		ResetPin => CRC_reset,		--asynchronous active high reset
		CRCpass => CRC_pass,			--high if no uncorrectable errors have been detected.
		ready => CRC_ready			--indicates CRC-check has completed
	);
	
	PROCESS (clk)
	BEGIN
		IF (RISING_EDGE(CLK)) THEN
			CASE state IS
				WHEN rx_idle =>
					IF (rx_busy = '1') THEN
						led(0) <= '1';
						f_busy_trigger <= TRUE;
					ELSIF (rx_busy = '0' AND f_busy_trigger) THEN
						state <= rx_move_b;
						f_busy_trigger <= FALSE;
					END IF;
				WHEN rx_move_b =>
					CASE bytes_received IS
						WHEN 0 =>
							CRC_input(31 downto 24) <= rx_buffer;
							bytes_received <= 1;
							state <= rx_idle;
						WHEN 1 =>
							CRC_input(23 downto 16) <= rx_buffer;
							bytes_received <= 2;
							state <= rx_idle;
						WHEN 2 =>
							CRC_input(15 downto 8) <= rx_buffer;
							bytes_received <= 3;
							state <= rx_idle;
						WHEN 3 =>
							CRC_input(7 downto 0) <= rx_buffer;
							bytes_received <= 0;
							state <= rx_CRC;
					END CASE;
				WHEN rx_CRC =>
					CASE CRC_state IS
						WHEN 0 =>	--Begin CRC check
							CRC_reset <= '1';
							CRC_state <= 1;
						WHEN 1 =>	--Lower reset-pin (also functions as a delay)
							CRC_reset <= '0';
							CRC_state <= 2;
						when 2 =>	--Additional delay
							CRC_state <= 3;
						WHEN 3 => 	--Wait for CRC check to complete
							IF (CRC_ready = '1' AND CRC_pass = '1') THEN	-- No errors
								CRC_state <= 0;
								state <= rx_move_r;
							ELSIF (CRC_ready = '1' AND CRC_pass = '0') THEN -- Error detected
								CRC_state <= 0;
								errorPin <= '1';
								state <= rx_move_r;
							END IF;
					END CASE;
				WHEN rx_move_r =>
					IF (save_state = 0) THEN
						save_state <= 1;
						IF (f_firstMove) THEN	-- Ram already points to correct address at startup
							f_firstMove <= FALSE;
						ELSE
							ram_addr <= ram_addr + 1;
						END IF;
					ELSIF (save_state = 1) THEN
						CASE cntr_move_r IS
							WHEN 0 => ram(TO_INTEGER(ram_addr)) <= CRC_output(15 downto 8);
							WHEN 1 => ram(TO_INTEGER(ram_addr)) <= CRC_output(7 downto 0);
						END CASE;
						save_state <= 2;
					ELSE
						save_state <= 0;
						IF (cntr_move_r = 1) THEN
							cntr_move_r <= 0;
							check_buffer(31 downto 16) <= CRC_output;
							state <= rx_check;
						ELSE
							cntr_move_r <= cntr_move_r + 1;
						END IF;
					END IF;
				WHEN rx_check =>
					IF (check_buffer(31 DOWNTO 16) = x"FFD9") THEN -- Latest 2 bytes match End-of-image identifier
						max_ram_addr <= ram_addr;
						state <= tx_init;
					ELSIF ((check_buffer(31 DOWNTO 25) = x"D9") AND (check_buffer(7 downto 0) = x"FF")) THEN -- End-of-image identifier found. Latest byte received is not part of image.
						max_ram_addr <= ram_addr - 1;
						state <= tx_init;
					ELSE	-- Identifier not found. Continue receiving data.
						check_buffer(15 downto 0) <= check_buffer(31 downto 16);
						state <= rx_idle;
					END IF;
				----------------------------------------------------------------------------------------------
				WHEN tx_init =>
					ram_addr <= (OTHERS => '0');
					state <= tx_move_r;
				WHEN tx_move_r =>
					tx_ena <= '0';
					IF (ram_addr = max_ram_addr + 1) THEN	-- All data has been transmitted
						state <= tx_end;
					ELSIF (NOT f_tx_move) THEN --Copy data from RAM to internal buffer
						tx_buffer <= ram(TO_INTEGER(ram_addr));
						f_tx_move <= TRUE;
					ELSE
						--Increment address
						ram_addr <= ram_addr + 1;
						f_tx_move <= FALSE;
						state <= tx_send;
					END IF;
				WHEN tx_send =>
					if (tx_busy = '0') THEN	-- Wait until the UART component is ready to transmit
						tx_ena <= '1';
						state <= tx_delay;
					END IF;
				WHEN tx_delay =>	-- Ensure the UART component has properly begun transmitting data
					IF (cntr_delay = 9) THEN
						cntr_delay <= 0;
						state <= tx_move_r;
					ELSE
						cntr_delay <= cntr_delay + 1;
					END IF;
				WHEN tx_end =>	-- End of transmission
					tx_ena <= '0';
			END CASE;
		END IF;
	END PROCESS;
end Behavioral;
