LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY Transmitter_Module IS
	PORT (
		CLK     : IN STD_LOGIC;
		input   : IN STD_LOGIC;
		output  : OUT STD_LOGIC;
		-- SRAM ports
		ram_addr : INOUT STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0'); -- Address pointer
		ram_data : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => 'Z'); -- Databus
		ram_ce : OUT STD_LOGIC := '0'; -- Chip Enable (always on)
		ram_we : OUT STD_LOGIC := '1'; -- Write Enable
		ram_oe : INOUT STD_LOGIC := '1'); -- Output Enable
	END Transmitter_Module;

ARCHITECTURE Behavioral OF Transmitter_Module IS
	COMPONENT uart	-- Instantiation
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
	
	-- UART Component signals
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
	
	--SRAM signals
	SIGNAL ram_tx : std_logic_vector(7 DOWNTO 0) := (OTHERS => '0'); -- Data TO the SRAM
	SIGNAL ram_rx : std_logic_vector(7 DOWNTO 0) := (OTHERS => '0'); -- Data FROM the SRAM
	
	--FSM flags
	TYPE rx_machine IS(disabled, idle, move_b, move_r, check);	--receive state machine data type
	TYPE tx_machine IS(disabled, init, move_r);	--transmit state machine data type
	SIGNAL	rx_state				:	rx_machine;									--receive state machine
	SIGNAL	tx_state				:	rx_machine;									--transmit state machine
	SIGNAL f_busy_trigger : BOOLEAN := FALSE;
	SIGNAL f_error : BOOLEAN := FALSE;
	SIGNAL f_rEnd : BOOLEAN := FALSE;
	
	--Counters
	SIGNAL even_bytes : BOOLEAN := FALSE;
	SIGNAL cntr_move_r : INTEGER RANGE 0 TO 3 := 0;
	SIGNAL save_state : INTEGER RANGE 0 TO 2 := 0;
	SIGNAL max_ram_addr : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');
	
	--Signal busses
	SIGNAL check_buffer : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL move_buffer 	: STD_LOGIC_VECTOR (31 DOWNTO 0) := (OTHERS => '0');
	
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
	
	PROCESS (ram_oe, ram_data, ram_tx) -- Tristate buffer, controlled by OE
	BEGIN
		IF (ram_oe = '0') THEN
			ram_data <= "ZZZZZZZZ";
			ram_rx <= ram_data;
		ELSE
			ram_data <= ram_tx;
			ram_rx <= ram_data;
		END IF;
	END PROCESS;

	PROCESS (clk)
	BEGIN
		IF (RISING_EDGE(CLK)) THEN
			CASE rx_state IS
				WHEN idle =>
					IF (rx_busy = '1') THEN
						f_busy_trigger <= TRUE;
					ELSIF (rx_busy = '0' AND f_busy_trigger) THEN
						rx_state <= move_b;
						f_busy_trigger <= FALSE;
					END IF;
				WHEN move_b =>
					IF (NOT even_bytes) THEN
						even_bytes <= TRUE;
						check_buffer(15 downto 8) <= rx_buffer;
						move_buffer(31 downto 24) <= rx_buffer;
						rx_state <= check;
					ELSE
						even_bytes <= FALSE;
						check_buffer(7 downto 0) <= rx_buffer;
						move_buffer(23 downto 16) <= rx_buffer;
						rx_state <= move_r;
					END IF;
				WHEN move_r =>
					IF (save_state = 0) THEN
						ram_addr <= ram_addr + 1;
						CASE cntr_move_r IS
							WHEN 0 => ram_tx <= move_buffer(31 downto 24);
							WHEN 1 => ram_tx <= move_buffer(23 downto 16);
							WHEN 2 => ram_tx <= move_buffer(15 downto 8);
							WHEN 3 => ram_tx <= move_buffer(7 downto 0);
						END CASE;
						save_state <= 1;
					ELSIF (save_state = 1) THEN
						ram_we <= '0';
						save_state <= 2;
					ELSE
						ram_we <= '1';
						save_state <= 0;
						IF (cntr_move_r = 3 AND f_rEnd) THEN
							cntr_move_r <= 0;
							max_ram_addr <= ram_addr;
							rx_state <= disabled;
							tx_state <= init;
						ELSIF (cntr_move_r = 3) THEN
							cntr_move_r <= 0;
							rx_state <= check;
						ELSE
							cntr_move_r <= cntr_move_r + 1;
						END IF;
					END IF;
				WHEN check =>
					IF (check_buffer = x"FFD9" OR check_buffer = x"D9FF") THEN
						f_rEnd <= true;
						-- even_bytes was inverted previously, so: TRUE = Uneven amount of bytes received, FALSE = Even amount of bytes.
						IF (NOT even_bytes) THEN
							-- All the data (+ CRC bits) has been moved to the SRAM - ready to transmit to Arduino
							rx_state <= disabled;
							max_ram_addr <= ram_addr;
							tx_state <= init;
						ELSE
							-- We have a single left-over byte to be moved to the SRAM.
							rx_state <= move_r;
						END IF;
					ELSE
						rx_state <= idle;
					END IF;
				WHEN OTHERS =>
					f_error <= TRUE;
			END CASE;
			CASE tx_state IS
				WHEN disabled =>
					tx_ena <= '0';
				WHEN init =>
					-- Ændré ram addr og sådan
				WHEN OTHERS =>
					f_error <= true;
			END CASE;
		END IF;
	END PROCESS;
END Behavioral;