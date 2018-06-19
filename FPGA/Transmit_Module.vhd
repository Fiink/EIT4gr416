--------------------------------------------------
-- RECEIVE:
--		x"FFD9" is used to determine when all data has been received
--
--		States:
--			rx_idle: Wait until the FPGA has received a byte of data
--			rx_move_b: Move received data to internal buffers (and apply CRC)
--			rx_move_r: After 2 bytes has been received, move these with corresponding CRC bits to RAM
--			rx_check: Check for end-of-image identifier. If found, start transmission.
--
--	TRANSMIT
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

ENTITY Transmit_Module IS
	PORT (
		CLK     : IN STD_LOGIC;
		led	  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
		input   : IN STD_LOGIC;
		output  : OUT STD_LOGIC
	);
	END Transmit_Module;

ARCHITECTURE Behavioral OF Transmit_Module IS
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
	
	--Internal memory
	TYPE ram_s IS ARRAY (0 TO 9999) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ram : ram_s := (OTHERS => (OTHERS => '0'));
	ATTRIBUTE ram_style : STRING;
	ATTRIBUTE ram_style OF ram : SIGNAL IS "distributed";
	SIGNAL ram_addr : UNSIGNED (13 DOWNTO 0) 	:= (OTHERS => '0');
	
	--FSM flags
	TYPE machine IS (rx_idle, rx_move_b, rx_move_r, rx_check, tx_init, tx_move_r, tx_send, tx_delay, tx_end);	--state machine data type
	SIGNAL state :	machine;									--transmit state machine
	SIGNAL f_error : BOOLEAN := FALSE;
	SIGNAL f_busy_trigger : BOOLEAN := FALSE;
	SIGNAL f_firstMove : BOOLEAN := TRUE;
	SIGNAL f_rEnd : BOOLEAN := FALSE;
	SIGNAL f_tx_move : BOOLEAN := FALSE;
	
	--Counters
	SIGNAL even_bytes : BOOLEAN := FALSE;
	SIGNAL cntr_move_r : INTEGER RANGE 0 TO 3 := 0;
	SIGNAL save_state : INTEGER RANGE 0 TO 3 := 0;
	SIGNAL max_ram_addr : UNSIGNED(13 DOWNTO 0) := (OTHERS => '0');
	SIGNAL cntr_delay : INTEGER RANGE 0 TO 1000 := 0;
	
	--Signal busses
	SIGNAL check_buffer : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL move_buffer 	: STD_LOGIC_VECTOR (31 DOWNTO 0) := (OTHERS => '0');
	

	
	SIGNAL fsm_tx_test : INTEGER RANGE 0 TO 50 := 0;
BEGIN
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
	
	-- CRC encoding
	move_buffer(15) <= move_buffer(27) XOR move_buffer(26) XOR move_buffer(23) XOR move_buffer(19);
	move_buffer(14) <= move_buffer(26) XOR move_buffer(25) XOR move_buffer(22) XOR move_buffer(18);
	move_buffer(13) <= move_buffer(25) XOR move_buffer(24) XOR move_buffer(21) XOR move_buffer(17);
	move_buffer(12) <= move_buffer(31) XOR move_buffer(24) XOR move_buffer(23) XOR move_buffer(20) XOR move_buffer(16);
	move_buffer(11) <= move_buffer(31) XOR move_buffer(30) XOR move_buffer(27) XOR move_buffer(26) XOR move_buffer(22);
	move_buffer(10) <= move_buffer(30) XOR move_buffer(29) XOR move_buffer(26) XOR move_buffer(25) XOR move_buffer(21);
	move_buffer(9)  <= move_buffer(31) XOR move_buffer(29) XOR move_buffer(28) XOR move_buffer(25) XOR move_buffer(24) XOR move_buffer(20);
	move_buffer(8)  <= move_buffer(31) XOR move_buffer(30) XOR move_buffer(28) XOR move_buffer(27) XOR move_buffer(24) XOR move_buffer(23) XOR move_buffer(19);
	move_buffer(7)  <= move_buffer(31) XOR move_buffer(30) XOR move_buffer(29) XOR move_buffer(27) XOR move_buffer(26) XOR move_buffer(23) XOR move_buffer(22) XOR move_buffer(18);
	move_buffer(6)  <= move_buffer(30) XOR move_buffer(29) XOR move_buffer(28) XOR move_buffer(26) XOR move_buffer(25) XOR move_buffer(22) XOR move_buffer(21) XOR move_buffer(17);
	move_buffer(5)  <= move_buffer(29) XOR move_buffer(28) XOR move_buffer(27) XOR move_buffer(25) XOR move_buffer(24) XOR move_buffer(21) XOR move_buffer(20) XOR move_buffer(16);
	move_buffer(4)  <= move_buffer(31) XOR move_buffer(28) XOR move_buffer(24) XOR move_buffer(20);
	move_buffer(3)  <= move_buffer(31) XOR move_buffer(30) XOR move_buffer(27) XOR move_buffer(23) XOR move_buffer(19);
	move_buffer(2)  <= move_buffer(30) XOR move_buffer(29) XOR move_buffer(26) XOR move_buffer(22) XOR move_buffer(18);
	move_buffer(1)  <= move_buffer(29) XOR move_buffer(28) XOR move_buffer(25) XOR move_buffer(21) XOR move_buffer(17);
	move_buffer(0)  <= move_buffer(28) XOR move_buffer(27) XOR move_buffer(24) XOR move_buffer(20) XOR move_buffer(16);

	PROCESS (clk)
	BEGIN
		IF (RISING_EDGE(CLK)) THEN
			CASE state IS
				WHEN rx_idle =>
					IF (rx_busy = '1') THEN
						f_busy_trigger <= TRUE;
						led(0) <= '1';
					ELSIF (rx_busy = '0' AND f_busy_trigger) THEN
						state <= rx_move_b;
						f_busy_trigger <= FALSE;
					END IF;
				WHEN rx_move_b =>
					IF (NOT even_bytes) THEN	--Skip moving to RAM
						even_bytes <= TRUE;
						check_buffer(15 downto 8) <= rx_buffer;
						move_buffer(31 downto 24) <= rx_buffer;
						state <= rx_check;
					ELSE
						even_bytes <= FALSE;		-- Move received data (+ CRC) to RAM
						check_buffer(7 downto 0) <= rx_buffer;
						move_buffer(23 downto 16) <= rx_buffer;
						state <= rx_move_r;
					END IF;
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
							WHEN 0 => ram(TO_INTEGER(ram_addr)) <= move_buffer(31 downto 24);
							WHEN 1 => ram(TO_INTEGER(ram_addr)) <= move_buffer(23 downto 16);
							WHEN 2 => ram(TO_INTEGER(ram_addr)) <= move_buffer(15 downto 8);
							WHEN 3 => ram(TO_INTEGER(ram_addr)) <= move_buffer(7 downto 0);
						END CASE;
						save_state <= 2;
					ELSIF (save_state = 2) THEN
						save_state <= 0;
						IF (cntr_move_r = 3 AND f_rEnd) THEN	-- Only relevant when end-of-image has been detected
							cntr_move_r <= 0; 
							max_ram_addr <= ram_addr;
							state <= tx_init;
						ELSIF (cntr_move_r = 3) THEN	-- Data + CRC has been moved to RAM
							cntr_move_r <= 0;
							state <= rx_check;
						ELSE
							cntr_move_r <= cntr_move_r + 1;
						END IF;
					END IF;
				WHEN rx_check =>
					IF ((check_buffer = x"FFD9") OR (check_buffer = x"D9FF")) THEN	-- check_buffer contains end-of-image identifier
						f_rEnd <= true;
						-- even_bytes was inverted previously, so: 
							-- TRUE = Uneven amount of bytes received,   
							-- FALSE = Even amount of bytes.
						IF (NOT even_bytes) THEN
							-- All the data (+ CRC bits) has already been moved to the RAM - ready to transmit to Arduino
							max_ram_addr <= ram_addr; 
							state <= tx_init;
						ELSE
							-- A single byte needs to be moved to the RAM.
							state <= rx_move_r;
						END IF;
					ELSE
						state <= rx_idle;
					END IF;
				----------------------------------------------------------------------------------------------
				WHEN tx_init =>
					ram_addr <= (OTHERS => '0');
					state <= tx_move_r;
				WHEN tx_move_r =>
					tx_ena <= '0';
					IF (ram_addr = (max_ram_addr + 1)) THEN	-- All data has been transmitted
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
					IF (tx_busy = '0') THEN	-- Wait until the UART component is ready to transmit
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
END Behavioral;

