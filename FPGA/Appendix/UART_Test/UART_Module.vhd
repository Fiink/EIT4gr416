library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity UART_Module is
    Port (  CLK : in  STD_LOGIC;
				input : in STD_LOGIC;
				ard_rdy : in STD_LOGIC;
				output : out STD_LOGIC := '1'
			);
end UART_Module;

architecture Behavioral of UART_Module is
-- LUT memory allocation
	TYPE ram_s IS ARRAY (0 TO 1000) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ram : ram_s := (OTHERS => (OTHERS => '0'));
	ATTRIBUTE ram_style : STRING;
	ATTRIBUTE ram_style OF ram : SIGNAL IS "distributed";
	
-- Input/Output buffer (Conversion between STD_LOGIC and STD_LOGIC_VECTOR)
	SIGNAL stck : STD_LOGIC_VECTOR (7 downto 0) := (OTHERS => '0');

-- Address pointers
	SIGNAL stck_addr : UNSIGNED (2 downto 0) := (OTHERS => '0');	-- 3 bits, resulting in 8 possible addresses
	SIGNAL ram_addr : UNSIGNED (9 downto 0) := (OTHERS => '0');		-- 10 bits, resulting in 1024 possible addresses
	SIGNAL s : INTEGER := 8;	-- Used to 'loop around' the stck_addr variable

-- Counters used in the system
	SIGNAL baud_time 	: INTEGER := 277; -- Used to set the frequency of which the FPGA reads the input pin
	SIGNAL baud_wait 	: INTEGER RANGE 0 TO baud_time := 0; -- Used for UART communication
	SIGNAL bits_read 	: INTEGER RANGE 0 TO 9 := 8;	-- Amount of bits sent/received during UART

-- Various flags
	SIGNAL f_receive 	: BOOLEAN := true; -- Receive data from Raspberry Pi
	SIGNAL f_transmit : BOOLEAN := false; -- Send data to Arduino
 
	SIGNAL f_readWrite	: BOOLEAN := false; -- (Receive) Saves current input to stack, (Transmit) Sets output to current active bit in buffer.
	SIGNAL f_incr 			: BOOLEAN := false; -- Increment address pointers
	SIGNAL f_move 			: BOOLEAN := false; -- For every 16th bit read, 2 bytes will be moved to the SRAM (along with corresponding CRC)
	SIGNAL f_wait 			: BOOLEAN := true; -- Wait a set amount of time until new data on input is available.
	SIGNAL f_waithalf 	: BOOLEAN := false; -- Wait a half bit-length, ensures the FPGA reads input when the signal is stable.
	SIGNAL f_startbit 	: BOOLEAN := false; -- Check for falling edge on the startbit in UART.
	SIGNAL f_incrRAM 		: BOOLEAN := false; -- Increment RAM counter when in f_move state.
	SIGNAL f_prep			: BOOLEAN := true; -- Prepare variables for transmit logic

begin

PROCESS(CLK)
	BEGIN
		IF (RISING_EDGE(CLK)) THEN
			IF (f_receive) THEN
				IF (f_readWrite) THEN
					baud_wait <= baud_wait + 1;
					stck(TO_INTEGER(stck_addr)) <= input;
					f_incr <= true;
					f_move <= true;
					f_readWrite <= false;
				ELSIF (f_move AND (TO_INTEGER(stck_addr) = 7)) THEN
					baud_wait <= baud_wait + 1;
					f_move <= false;
					ram(TO_INTEGER(ram_addr)) <= stck;
					f_incrRam <= true;
				ELSIF (f_incr) THEN
					baud_wait <= baud_wait + 1;
					f_move <= false;
					stck_addr <= (stck_addr + 1) REM s;
					IF (f_incrRam) THEN
						ram_addr <= ram_addr + 1;
						f_incrRam <= false;
					END IF;
					f_wait <= true;
					f_incr <= false;
				ELSIF (TO_INTEGER(ram_addr) = 50) THEN	-- EXIT CONDITION
					f_receive <= false;
					f_transmit <= true;
				ELSIF (f_wait) THEN
					IF (bits_read = 8) THEN
						IF (baud_wait = baud_time) THEN 
							IF ((input = '0') AND (f_startbit)) THEN	-- Wait for falling edge
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
							f_wait <= false;
							f_readWrite <= true;
						ELSE
							baud_wait <= baud_wait + 1;
						END IF;
					END IF;
				ELSIF (f_waithalf) THEN
					IF (baud_wait = baud_time/2) THEN
						baud_wait <= 0;
						bits_read <= 0;
						f_waithalf <= false;
						f_wait <= true;
					ELSE
						baud_wait <= baud_wait + 1;
					END IF;
				END IF;	
			ELSIF (f_transmit) THEN
				IF (f_prep) THEN
					ram_addr <= (OTHERS => '0');
					f_readWrite <= false;
					f_incr <= false;
					f_wait <= true;
					bits_read <= 9;
					baud_wait <= 0;
					f_prep <= false;
					stck_addr <= "000";
				------------------------------
				ELSIF (f_readWrite) THEN
					baud_wait <= baud_wait + 1;
					IF (bits_read = 0) THEN -- Startbit
						output <= '0';
					ELSIF ((bits_read >= 1) AND (bits_read <= 8)) THEN -- Data
						output <= stck(to_integer(stck_addr));
					ELSIF (bits_read = 9) THEN -- Stopbit
						output <= '1';
					END IF;
					f_readwrite <= false;
					f_incr <= true;
				ELSIF (f_incr) THEN
					baud_wait <= baud_wait + 1;
					IF ((bits_read >= 1) AND (bits_read <= 8)) THEN
						stck_addr <= stck_addr + 1;	-- Send in reverse order
					ELSIF (bits_read = 9) THEN
						stck_addr <= "000";
						ram_addr <= ram_addr + 1;
					END IF;
					f_incr <= false;
					f_wait <= true;
				ELSIF (TO_INTEGER(ram_addr) = 50) THEN
					f_transmit <= false;
				ELSIF (f_wait) THEN
					IF (bits_read = 9) THEN
						stck <= ram(to_integer(ram_addr));
						IF (baud_wait = baud_time) THEN
							IF (ard_rdy = '1') THEN
								bits_read <= 0;
								baud_wait <= 0;
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
				END IF;
			END IF;
		END IF;
END PROCESS;
end Behavioral;

