-- The transmitter FPGA module is not complete, since the FPGA 
-- could never be connected to either the Raspberry Pi or the Arduino.
-- The most recent working code can however be seen below, which is functional
-- in simulations. 
-- The module does however process the received data correctly, including appending the correct 
-- CRC bits.
-- 
-- The current code, as seen below, has the following features / important characteristics:
--		- CRC calculation
--		- Internal RAM (currently 1001 x 32 to decrease the time taken to synthesize for tests)
--		- Finite State Machine
--			- Receiver FSM, receives, encodes and stores data in RAM
--			- Transmitter FSM, loads data from RAM and transmits this (Note: UART does still not work as intended)
--
-- The following features has been tested individually, but are not implemented in this code.
--		- Physical SRAM implementation (250.000 x 8)
--			- The various buffers must be changed to accomedate for the new RAM size (32 => 8)
--
-- This file is expected to be updated with a proper UART implementation, 
-- as well as use of the on-board SRAM using the corresponding I/O pins. 



LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY TransmitterModule IS
	PORT 
	(  CLK      : IN STD_LOGIC;
		input    : IN STD_LOGIC;
		ard_rdy	: IN STD_LOGIC;
		led		: OUT STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
		output   : OUT STD_LOGIC := '1'
		
	);
END TransmitterModule;

ARCHITECTURE Behavioral OF TransmitterModule IS
	------
	-- Memory Definitions
	------
	-- Declaration of type and signal of a 16000-element SRAM with each element being 16 bit wide.
	-- The built-in memory is used instead of SRAM, as the external chip cannot be simulated
	TYPE ram_s IS ARRAY (0 TO 1000) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL ram : ram_s := (OTHERS => (OTHERS => '0'));
	-- Default RAM-type is block (BRAM). Setting ram_style to "distributed" changes this to SRAM.
	ATTRIBUTE ram_style : STRING;
	ATTRIBUTE ram_style OF ram : SIGNAL IS "distributed";
	
	-- Buffer signal bussess
	SIGNAL check_buffer	: STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL move_buffer 	: STD_LOGIC_VECTOR (31 DOWNTO 0) := (OTHERS => '0');
	SIGNAL out_buffer 	: STD_LOGIC_VECTOR (31 downto 0) := (OTHERS => '0');
	SIGNAL stck 			: STD_LOGIC_VECTOR (31 downto 0) := (OTHERS => '0');
	
	-- Address pointers
	SIGNAL ram_addr 	: unsigned (13 DOWNTO 0) 	:= (OTHERS => '0');
	SIGNAL stck_addr 	: unsigned (5 DOWNTO 0) 	:= (OTHERS => '0');
	SIGNAL out_addr	: unsigned (4 downto 0)		:= (OTHERS => '0');
	SIGNAL s 			: INTEGER := 32; -- Variable 's' defines length of stack. Used to 'roll-over' when the number is reached (e.g. 31+1 => 0)
	------
	-- Other signal definitions (e.g. FSM)
	------
	-- Counters used in the system
	SIGNAL baud_time 	: INTEGER := 277; -- Used to set the frequency of which the FPGA reads the input pin
	SIGNAL baud_wait 	: INTEGER RANGE 0 TO baud_time := 0; -- Used for UART communication between the FPGA and Raspberry Pi
	SIGNAL inputFilter : INTEGER RANGE 0 TO 20 := 10;
	SIGNAL threshold : INTEGER := 20;
	SIGNAL bits_read 	: INTEGER RANGE 0 TO 9 := 8;	-- Amount of bits sent/received during UART
	SIGNAL byte_cntr 	: INTEGER RANGE 0 TO 4 := 0;
	SIGNAL int_rEnd 	: STD_LOGIC_VECTOR (2 downto 0) := (OTHERS => '0');	-- Receive-End bit vector. Used instead of 5 seperate flags
	SIGNAL max_ramaddr: unsigned (13 downto 0)	:= (OTHERS => '0');	-- When finished receiving data, the highest relevant ram address is saved


	-- Flags for the Finite State Machine
	SIGNAL f_receive 	: BOOLEAN := true; -- Receive data from Raspberry Pi
	SIGNAL f_transmit : BOOLEAN := false; -- Send data to Arduino
 
	SIGNAL f_readWrite	: BOOLEAN := false; -- (Receive) Saves current input to stack, (Transmit) Sets output to current active bit in buffer.
	SIGNAL f_incr 			: BOOLEAN := false; -- Increment address pointers
	SIGNAL f_move 			: BOOLEAN := false; -- For every 16th bit read, 2 bytes will be moved to the SRAM (along with corresponding CRC)
	SIGNAL f_wait 			: BOOLEAN := true; -- Wait a set amount of time until new data on input is available.
	SIGNAL f_waithalf 	: BOOLEAN := false; -- Wait a half bit-length, ensures the FPGA reads input when the signal is stable.
	SIGNAL f_startbit 	: BOOLEAN := false; -- Check for falling edge on the startbit in UART.
	SIGNAL f_rSkipMove 	: BOOLEAN := true; -- Used initially to delay moving data from the move_buffer to SRAM, as it would be empty.
	SIGNAL f_rEven 		: BOOLEAN := false; -- Currently have an even amount of bytes received, ready to move to RAM
	SIGNAL f_incrRAM 		: BOOLEAN := false; -- Increment RAM counter when in f_move state.
	SIGNAL f_rEnd 			: BOOLEAN := false; -- Finished receiving from Raspberry Pi
	SIGNAL f_preptransmit: BOOLEAN := true; -- Prepare variables for transmit logic
	SIGNAL f_tEnd			: BOOLEAN := false; -- Finished transmitting to Arduino
	
	SIGNAL error : STD_LOGIC := '0'; -- Indicates an error, used to light an LED.
		
	signal Startbit, Stopbit : boolean := false; -- Helps indicate when start/stopbits occur in simulations

BEGIN
	led(7) <= error;
	------
	-- Bus assignments
	------
	-- Used to convert std_logic to std_logic_vector, which can be saved in the SRAM
	move_buffer(31) <= stck(to_integer((stck_addr - 24) REM s));
	move_buffer(30) <= stck(to_integer((stck_addr - 25) REM s));
	move_buffer(29) <= stck(to_integer((stck_addr - 26) REM s));
	move_buffer(28) <= stck(to_integer((stck_addr - 27) REM s));
	move_buffer(27) <= stck(to_integer((stck_addr - 28) REM s));
	move_buffer(26) <= stck(to_integer((stck_addr - 29) REM s));
	move_buffer(25) <= stck(to_integer((stck_addr - 30) REM s));
	move_buffer(24) <= stck(to_integer((stck_addr - 31) REM s));
	move_buffer(23) <= stck(to_integer((stck_addr - 16) REM s));
	move_buffer(22) <= stck(to_integer((stck_addr - 17) REM s));
	move_buffer(21) <= stck(to_integer((stck_addr - 18) REM s));
	move_buffer(20) <= stck(to_integer((stck_addr - 19) REM s));
	move_buffer(19) <= stck(to_integer((stck_addr - 20) REM s));
	move_buffer(18) <= stck(to_integer((stck_addr - 21) REM s));
	move_buffer(17) <= stck(to_integer((stck_addr - 22) REM s));
	move_buffer(16) <= stck(to_integer((stck_addr - 23) REM s));

	-- Characters indicating end of image: ÿÙ (HEX: FF D9)
	check_buffer(15) <= stck(to_integer((stck_addr - 8) REM s)); -- ÿ
	check_buffer(14) <= stck(to_integer((stck_addr - 9) REM s));
	check_buffer(13) <= stck(to_integer((stck_addr - 10) REM s));
	check_buffer(12) <= stck(to_integer((stck_addr - 11) REM s));
	check_buffer(11) <= stck(to_integer((stck_addr - 12) REM s));
	check_buffer(10) <= stck(to_integer((stck_addr - 13) REM s));
	check_buffer(9)  <= stck(to_integer((stck_addr - 14) REM s));
	check_buffer(8)  <= stck(to_integer((stck_addr - 15) REM s));
	check_buffer(7)  <= stck(to_integer((stck_addr) REM s));     -- Ù
	check_buffer(6)  <= stck(to_integer((stck_addr - 1) REM s));
	check_buffer(5)  <= stck(to_integer((stck_addr - 2) REM s));
	check_buffer(4)  <= stck(to_integer((stck_addr - 3) REM s));
	check_buffer(3)  <= stck(to_integer((stck_addr - 4) REM s));
	check_buffer(2)  <= stck(to_integer((stck_addr - 5) REM s));
	check_buffer(1)  <= stck(to_integer((stck_addr - 6) REM s));
	check_buffer(0)  <= stck(to_integer((stck_addr - 7) REM s));
	
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

PROCESS (CLK)
	BEGIN
		IF (rising_edge(CLK)) THEN		
		------
		-- Receive logic
		------
			IF (f_receive) THEN
				IF (f_readWrite) THEN
					baud_wait <= baud_wait + 1;
					f_incr <= true;
					f_move <= true;
					f_rEven <= false;
					IF (baud_wait <= 38) THEN	-- We have this many clock cycles to check input
						-- First check if inputFilter has reached threshold-values
						IF (inputFilter = threshold) THEN -- Input is '1'
							stck(to_integer(stck_addr)) <= '1';
							f_readWrite <= false;
						ELSIF (inputFilter = 0) THEN -- Input is '0'
							stck(to_integer(stck_addr)) <= '0';
							f_readWrite <= false;
						-- Unsure of input - continue changing inputFilter
						ELSIF (input = '1') THEN
							inputFilter <= inputFilter + 1;
						ELSIF (input = '0') THEN
							inputFilter <= inputFilter - 1;
						END IF;
					ELSE 
						-- While the FPGA isn't certain, timing is starting to be an issue, and it is needed to
						-- push an input to the stack.
						IF (inputFilter >= 10) THEN
							stck(to_integer(stck_addr)) <= '1';
							f_readWrite <= false;	
						ELSE
							stck(to_integer(stck_addr)) <= '0';
							f_readWrite <= false;
						END IF;
					END IF;
				-- Trigger for every even byte received (stck_addr = 15, 31, 47)
				ELSIF (f_move AND ((to_integer(stck_addr) = 15) OR (to_integer(stck_addr) = 31))) THEN
					baud_wait <= baud_wait + 1;
					f_move <= false;
					f_rEven <= true; 
					IF (NOT f_rSkipMove) THEN
						ram(to_integer(ram_addr)) <= move_buffer;
						f_incrRam <= true;
					ELSE
						f_rSkipMove <= false;
					END IF;
				-- Trigger if check_buffer contains end of image (after a whole byte is read)
				ELSIF ((check_buffer = x"FFD9") AND (NOT f_rEnd) AND (f_incr) AND 
					((to_integer(stck_addr) = 7) OR (to_integer(stck_addr) = 15) OR (to_integer(stck_addr) = 23) OR (to_integer(stck_addr) = 31))) THEN
					f_rEnd <= true;
					f_wait <= false;
					f_incr <= false;
				-- Increment stack counter (and RAM counter if necessary)
				ELSIF (f_incr) THEN
					baud_wait <= baud_wait + 1;
					f_move <= false;
					stck_addr <= (stck_addr + 1) REM s;
					IF (f_incrRam) THEN
						ram_addr <= ram_addr + 1;
						f_incrRam <= false;
					END IF;
					f_incr <= false;
					f_wait <= true;
				-- Wait until it is time to read again (following UART protocol)
				ELSIF (f_wait) THEN
					IF (bits_read = 8) THEN 
						IF (baud_wait = baud_time) THEN 
							IF ((input = '0') AND (f_startbit)) THEN
								baud_wait <= 0;
								f_wait <= false;
								f_startbit <= false;
								f_waithalf <= true;
							ELSIF (input = '1') THEN
								f_startbit <= true;
							END IF;
						ELSE
							baud_wait <= baud_wait + 1;
						END IF;
					ELSE
						IF (baud_wait = baud_time) THEN
							baud_wait <= 0;
							bits_read <= bits_read + 1;
							inputFilter <= 10;
							f_wait <= false;
							f_readWrite <= true;
						ELSE
							baud_wait <= baud_wait + 1;
						END IF;
					END IF;
				-- Wait half a bit length
				ELSIF (f_waithalf) THEN
					IF (baud_wait = baud_time/2) THEN
						baud_wait <= 0;
						bits_read <= 0;
						f_waithalf <= false;
						f_wait <= true;
					ELSE
						baud_wait <= baud_wait + 1;
					END IF;
				--Finished receiving, moving final bytes to memory
				ELSIF (f_rEnd) THEN
					CASE int_rEnd IS
						when "000" => -- Check whether the amount of bytes is even or uneven
							IF (f_rEven) THEN
								ram_addr <= ram_addr + 1; -- Since a word has just been placed into the RAM, the address has to be incremented
								int_rEnd <= "001";
							ELSE
								stck_addr <= (stck_addr + 8) REM s;
								int_rEnd <= "101";
							END IF;
					-- Even amount of bytes:
						WHEN "001" =>	-- End even 1
							stck_addr <= (stck_addr + 16) REM s;
							int_rEnd <= "010";
						WHEN "010" => -- End even 2
							ram(to_integer(ram_addr)) <= move_buffer;
							max_ramaddr <= ram_addr;
							f_receive <= false;
							f_transmit <= true;
					-- Uneven amount of bytes:
						WHEN "101" => -- End uneven 1
							ram(to_integer(ram_addr)) <= move_buffer;
							int_rEnd <= "110";
						WHEN "110" => -- End uneven 2
							stck_addr <= (stck_addr + 16) REM s; 
							ram_addr <= ram_addr + 1;
							int_rEnd <= "111";
						WHEN "111" => -- End uneven 3
							ram(to_integer(ram_addr)) <= move_buffer;
							max_ramaddr <= ram_addr;
							f_receive <= false;
							f_transmit <= true;
						WHEN others =>
							error <= '1';
					END CASE;
				END IF;
		------
		-- Transmit logic
		------
			ELSIF (f_transmit) THEN	
				IF (f_preptransmit) THEN
					-- Set start-parameters. State should only be active once.
					f_readWrite <= false;
					f_incr <= false;
					f_wait <= true;
					f_waithalf <= false;
					bits_read <= 9;
					byte_cntr <= 4;
					ram_addr <= (others => '0');
					out_addr <= "11000"; -- 7
					baud_wait <= 0;
					f_tEnd <= false;
					f_preptransmit <= false;
			--------------------------------------------
				-- Set output
				ELSIF (f_readWrite) THEN
					baud_wait <= baud_wait + 1;
					IF (bits_read = 0) THEN -- Starbit
						output <= '0';
						Startbit <= true;
					ELSIF ((bits_read >= 1) AND (bits_read <= 8)) THEN -- Data
						output <= out_buffer(to_integer(out_addr));
					ELSIF (bits_read = 9) THEN -- Stopbit
						output <= '1';
						Stopbit <= true;
					END IF;
					f_readwrite <= false;
					f_incr <= true;
				-- Control address pointers
				ELSIF (f_incr) THEN
					baud_wait <= baud_wait + 1;
					Stopbit <= false;
					Startbit <= false;
					IF ((NOT (bits_read = 0)) AND (NOT (bits_read = 9))) THEN
						IF ((out_addr = "01111") OR (out_addr = "10111") OR (out_addr = "11111")) THEN -- 'End' of byte 1-3, set address to next byte
							out_addr <= out_addr - 15;
						ELSIF (out_addr = "00111") THEN -- 'End' of byte nr. 4, set address to first byte, increment RAM address
							out_addr <= "11000";	-- = 7
							IF (NOT (ram_addr = max_ramaddr)) THEN
								ram_addr <= ram_addr + 1;
							ELSE
								f_tEnd <= true;	-- End of transmission
							END IF;
						ELSE
							out_addr <= out_addr + 1;
						END IF;
					END IF;
					f_incr <= false;
					f_move <= true;
					f_wait <= true;
				-- Wait until enough time has passed (following UART protocol)
				ELSIF (f_wait) THEN
					IF (bits_read = 9) THEN
						out_buffer <= ram(to_integer(ram_addr));
						IF (baud_wait = baud_time) THEN
							IF (byte_cntr = 4) THEN
								IF (f_tEnd) THEN
									f_wait <= false;
								ELSIF (ard_rdy = '1') THEN
									byte_cntr <= 0;
								ELSE
								END IF;
							ELSE
								baud_wait <= 0;
								bits_read <= 0;
								byte_cntr <= byte_cntr + 1;
								f_readWrite <= true;
								f_wait <= false;
							END IF;
						ELSE
							baud_wait <= baud_wait +1;
						END IF;
					ELSE
						-- Wait 278 clk periods (UART)
						IF (baud_wait = baud_time) THEN
							baud_wait <= 0;
							bits_read <= bits_read + 1;
							f_wait <= false;
							f_readWrite <= true;
						ELSE
							baud_wait <= baud_wait + 1;
						END IF;
					END IF;
				ELSIF (f_tEnd) THEN
					-- Finished transmitting.
				END IF;
			END IF;
		END IF;
	END PROCESS;
END Behavioral;