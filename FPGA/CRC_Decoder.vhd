library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CRC_Decoder is
    Port ( CLK : in  STD_LOGIC;
           input : in  STD_LOGIC_VECTOR (31 downto 0)		:= x"00000000";
           output : out  STD_LOGIC_VECTOR (15 downto 0)	:= x"0000";
           ResetPin : in  STD_LOGIC := '0';
			  CRCpass : out STD_LOGIC := '0';	-- High if CRC-check passed
			  ready : out  STD_LOGIC := '0');	-- High when finished
end CRC_Decoder;

architecture Behavioral of CRC_Decoder is
	signal	dataword:	STD_LOGIC_VECTOR (15 downto 0)	:= x"0000";
	signal	crc:			STD_LOGIC_VECTOR (15 downto 0)	:= x"0000";
	
	-- FSM flags
	signal f_reset:		boolean := false; -- Reset module
	signal f_resetpin:	boolean := true;  -- Remember pin state
	signal f_newword:		boolean := true;  -- 1st state
	signal f_calcCRC:		boolean := false; -- 2nd state
	signal f_check:		boolean := false; -- 3rd state
	signal f_pass:			boolean := false; -- High if CRC-check passed
	
	
begin
	output <= dataword;

	process(CLK)
	begin
		if (rising_edge(CLK)) then -- Only update when clock is rising
			------
			--  Reset logic
			------
			if (not f_resetpin) then		-- If reset pin state was low last clock cycle
				if (ResetPin = '1') then	-- If reset pin is currently high
					f_reset <= true;
					f_resetpin <= true;		-- Remember pin state
				end if;
			elsif (ResetPin = '0') then	-- When reset pin is low again, reset f_resetpin, so we're ready for another reset
				f_resetpin <= false;
			end if;
			if (f_reset) then					-- Set initial state of module (i.e. start reading new word)
				f_reset		<= false;
				f_newword	<= true;
				f_calcCRC	<= false;
				f_pass		<= false;
				f_check		<= false;
				CRCpass	   <= '0';
				ready			<= '0';
			------
			--  Decoder logic
			------
			elsif (f_newword) then
				dataword <= input(31 downto 16);		-- Load data word from input, as it may be necessary to manipulate it
				f_newword <= false;
				f_calcCRC <= true;	-- Move to next state
			elsif (f_calcCRC) then
				-- CRC bit calculation from received dataword and CRC
				crc(15) <= input(15) XOR dataword(11)	XOR dataword(10)	XOR dataword(7) 	XOR dataword(3);
				crc(14) <= input(14) XOR dataword(10) 	XOR dataword(9) 	XOR dataword(6)	XOR dataword(2);
				crc(13) <= input(13) XOR dataword(9) 	XOR dataword(8) 	XOR dataword(5) 	XOR dataword(1);
				crc(12) <= input(12) XOR dataword(15) 	XOR dataword(8) 	XOR dataword(7) 	XOR dataword(4)	XOR dataword(0);
				crc(11) <= input(11) XOR dataword(15) 	XOR dataword(14) 	XOR dataword(11) 	XOR dataword(10) 	XOR dataword(6);
				crc(10) <= input(10) XOR dataword(14) 	XOR dataword(13) 	XOR dataword(10) 	XOR dataword(9) 	XOR dataword(5);
				crc(9)  <= input(9) 	XOR dataword(15) 	XOR dataword(13) 	XOR dataword(12) 	XOR dataword(9) 	XOR dataword(8)	XOR dataword(4);
				crc(8)  <= input(8) 	XOR dataword(15) 	XOR dataword(14) 	XOR dataword(12) 	XOR dataword(11) 	XOR dataword(8) 	XOR dataword(7)	XOR dataword(3);
				crc(7)  <= input(7) 	XOR dataword(15) 	XOR dataword(14) 	XOR dataword(13) 	XOR dataword(11) 	XOR dataword(10) 	XOR dataword(7) 	XOR dataword(6)	XOR dataword(2);
				crc(6)  <= input(6) 	XOR dataword(14) 	XOR dataword(13) 	XOR dataword(12) 	XOR dataword(10) 	XOR dataword(9) 	XOR dataword(6) 	XOR dataword(5) 	XOR dataword(1);
				crc(5)  <= input(5) 	XOR dataword(13) 	XOR dataword(12) 	XOR dataword(11) 	XOR dataword(9) 	XOR dataword(8) 	XOR dataword(5) 	XOR dataword(4) 	XOR dataword(0);
				crc(4)  <= input(4) 	XOR dataword(15) 	XOR dataword(12) 	XOR dataword(8) 	XOR dataword(4);
				crc(3)  <= input(3) 	XOR dataword(15) 	XOR dataword(14) 	XOR dataword(11) 	XOR dataword(7) 	XOR dataword(3);
				crc(2)  <= input(2) 	XOR dataword(14) 	XOR dataword(13) 	XOR dataword(10) 	XOR dataword(6) 	XOR dataword(2);
				crc(1)  <= input(1) 	XOR dataword(13) 	XOR dataword(12) 	XOR dataword(9) 	XOR dataword(5) 	XOR dataword(1);
				crc(0)  <= input(0) 	XOR dataword(12) 	XOR dataword(11) 	XOR dataword(8) 	XOR dataword(4) 	XOR dataword(0);	
				f_calcCRC <= false;
				f_check <= true;
				f_pass <= false;			-- Ensure pass-flag is low. 
			elsif (f_check) then	
				case crc is					
					------
					--  No errors
					------
					when 	x"0000"	=>	
									f_check <= false;
									f_pass <= true; 
					------
					--  Single CRC bit error
					------
					when x"0001" | x"0002" | x"0004" | x"0008" | x"0010" | x"0020" | x"0040" | x"0080" | x"0100" | x"0200" | x"0400" | x"0800" | x"1000" | x"2000" | x"4000" | x"8000" => 
									f_pass <= true;
									f_check <= false;				
					------
					--  Single data bit error
					--   Recalculate CRC afterwards to ensure dataword is correct
					------
					when	x"1021"	=>
									dataword(0) <= dataword(0) XOR '1';	-- Data bit 0 error
									f_calccrc <= true;
					when	x"2042"	=>
									dataword(1) <= dataword(1) XOR '1';	-- Data bit 1 error
									f_calccrc <= true;
					when	x"4084"	=>
									dataword(2) <= dataword(2) XOR '1';	-- Data bit 2 error
									f_calccrc <= true;
					when	x"8108"	=>
									dataword(3) <= dataword(3) XOR '1';	-- Data bit 3 error
									f_calccrc <= true;
					when	x"1231"	=>
									dataword(4) <= dataword(4) XOR '1';	-- Data bit 4 error
									f_calccrc <= true;
					when	x"2462"	=>
									dataword(5) <= dataword(5) XOR '1';	-- Data bit 5 error
									f_calccrc <= true;
					when	x"48C4"	=>
									dataword(6) <= dataword(6) XOR '1';	-- Data bit 6 error
									f_calccrc <= true;
					when	x"9188"	=>
									dataword(7) <= dataword(7) XOR '1';	-- Data bit 7 error
									f_calccrc <= true;
					when	x"3331"	=>
									dataword(8) <= dataword(8) XOR '1';	-- Data bit 8 error
									f_calccrc <= true;
					when	x"6662"	=>
									dataword(9) <= dataword(9) XOR '1';	-- Data bit 9 error
									f_calccrc <= true;
					when	x"CCC4"	=>
									dataword(10) <= dataword(10) XOR '1';	-- Data bit 10 error
									f_calccrc <= true;
					when	x"89A9"	=>
									dataword(11) <= dataword(11) XOR '1';	-- Data bit 11 error
									f_calccrc <= true;
					when	x"0373"	=>
									dataword(12) <= dataword(12) XOR '1';	-- Data bit 12 error
									f_calccrc <= true;
					when	x"06E6"	=>
									dataword(13) <= dataword(13) XOR '1';	-- Data bit 13 error
									f_calccrc <= true;
					when	x"0DCC"	=>
									dataword(14) <= dataword(14) XOR '1';	-- Data bit 14 error
									f_calccrc <= true;
					when	x"1B98"	=>
									dataword(15) <= dataword(15) XOR '1';	-- Data bit 15 error 
									f_calccrc <= true;
					------
					--  Multiple bit errors
					------
					when others	   =>	
									f_pass <= false;
									f_check <= false;	
				end case;
			else
				if (f_pass) then				-- CRC-check passed
					CRCpass <= '1';
					ready <= '1';
				elsif (not f_pass) then		-- CRC-check failed
					CRCpass <= '0';
					ready <= '1';
				end if;
			end if;
		end if;
	end process;
end Behavioral;