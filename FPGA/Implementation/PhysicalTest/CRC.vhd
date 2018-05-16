library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;


entity CRC is
    Port (	clk : in   STD_LOGIC;
				led : out  STD_LOGIC_VECTOR (7 downto 0)
	 );
end CRC;

architecture Behavioral of CRC is
	SIGNAL encodedword : STD_LOGIC_VECTOR (31 downto 0);	-- Appends CRC to the data
	SIGNAL currentword : STD_LOGIC_VECTOR (31 downto 0);	-- Current word being decoded
	SIGNAL decodedword : STD_LOGIC_VECTOR (15 downto 0);
	
	SIGNAL fsm : STD_LOGIC_VECTOR (3 downto 0) := x"1";	-- Finite state machine controller
	SIGNAL f_decode : BOOLEAN := false;
	SIGNAL f_decodeready : BOOLEAN := true;
	SIGNAL crcpass, ready : STD_LOGIC;
	
	SIGNAL ResetPin : STD_LOGIC := '0';

	-- Instantiation of the CRC decoder
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

begin
	Inst_CRC_Decoder: CRC_Decoder PORT MAP(	-- Port declaration
		CLK => CLK,
		input => currentword,
		output => decodedword,
		ResetPin => ResetPin,
		CRCpass => CRCpass,
		ready => ready
	);

	encodedword(15) <= encodedword(27) XOR encodedword(26) XOR encodedword(23) XOR encodedword(19);
	encodedword(14) <= encodedword(26) XOR encodedword(25) XOR encodedword(22) XOR encodedword(18);
	encodedword(13) <= encodedword(25) XOR encodedword(24) XOR encodedword(21) XOR encodedword(17);
	encodedword(12) <= encodedword(31) XOR encodedword(24) XOR encodedword(23) XOR encodedword(20) XOR encodedword(16);
	encodedword(11) <= encodedword(31) XOR encodedword(30) XOR encodedword(27) XOR encodedword(26) XOR encodedword(22);
	encodedword(10) <= encodedword(30) XOR encodedword(29) XOR encodedword(26) XOR encodedword(25) XOR encodedword(21);
	encodedword(9)  <= encodedword(31) XOR encodedword(29) XOR encodedword(28) XOR encodedword(25) XOR encodedword(24) XOR encodedword(20);
	encodedword(8)  <= encodedword(31) XOR encodedword(30) XOR encodedword(28) XOR encodedword(27) XOR encodedword(24) XOR encodedword(23) XOR encodedword(19);
	encodedword(7)  <= encodedword(31) XOR encodedword(30) XOR encodedword(29) XOR encodedword(27) XOR encodedword(26) XOR encodedword(23) XOR encodedword(22) XOR encodedword(18);
	encodedword(6)  <= encodedword(30) XOR encodedword(29) XOR encodedword(28) XOR encodedword(26) XOR encodedword(25) XOR encodedword(22) XOR encodedword(21) XOR encodedword(17);
	encodedword(5)  <= encodedword(29) XOR encodedword(28) XOR encodedword(27) XOR encodedword(25) XOR encodedword(24) XOR encodedword(21) XOR encodedword(20) XOR encodedword(16);
	encodedword(4)  <= encodedword(31) XOR encodedword(28) XOR encodedword(24) XOR encodedword(20);
	encodedword(3)  <= encodedword(31) XOR encodedword(30) XOR encodedword(27) XOR encodedword(23) XOR encodedword(19);
	encodedword(2)  <= encodedword(30) XOR encodedword(29) XOR encodedword(26) XOR encodedword(22) XOR encodedword(18);
	encodedword(1)  <= encodedword(29) XOR encodedword(28) XOR encodedword(25) XOR encodedword(21) XOR encodedword(17);
	encodedword(0)  <= encodedword(28) XOR encodedword(27) XOR encodedword(24) XOR encodedword(20) XOR encodedword(16);


PROCESS (CLK)
BEGIN
	IF (rising_edge(CLK)) THEN
		IF (f_decode) THEN			--	An extra clock cycle is used to start the decoder, meaning
			IF (f_decodeready) THEN	-- f_decode can be set high the same cycle the encodedword is set
				f_decodeready <= FALSE;
				ResetPin <= '1';
			ELSIF (ready = '1') THEN
				f_decodeready <= TRUE;
				ResetPin <= '0';
				f_decode <= false;
			END IF;
		ELSE
			CASE fsm IS
				WHEN x"1" =>
					encodedword(31 downto 16) <= x"AAAA";	-- b'1010 1010 1010 1010
					fsm <= fsm + 1;
				WHEN x"2" =>
					currentword <= encodedword;
					f_decode <= true;
					fsm <= fsm + 1;
				WHEN x"3" =>
					IF (Currentword = x"AAAAE615") THEN	-- Test encoder
						led(0) <= '1';
					END IF;
					IF (CRCPass = '1') THEN	-- Test decoder, no bit errors
						led(1) <= '1';
					END IF;
					Currentword(25) <= Currentword(25) XOR '1';	-- Flip databit 10
					f_decode <= true;
					fsm <= fsm + 1;
				WHEN x"4" =>
					IF (CRCPass = '1') THEN -- Test decoder, single data bit error: Check if CRC passed
						led(2) <= '1';
					END IF;
					IF (decodedword = x"AAAA") THEN -- Test decoder, single data bit error: Check if data was corrected
						led(3) <= '1';
					END IF;
					Currentword(25) <= Encodedword(25) XOR '1';	-- Revert databit 10 til original
					Currentword(5) <= Encodedword(5) XOR '1';	-- Flip CRC bit 6
					f_decode <= true;
					fsm <= fsm + 1;
				WHEN x"5" =>
					IF (CRCPASS <= '1') THEN	-- Test decoder, single CRC bit error
						led(4) <= '1';
					END IF;
					IF (decodedword = x"AAAA") THEN -- Ensure data hasn't changed due to CRC error
						led(5) <= '1';
					END IF;
					Currentword(25) <= Currentword(25) XOR '1';	-- Flip databit 10, so two bits are in error (Data + CRC)
					f_decode <= true;
					fsm <= fsm + 1;
				WHEN x"6" =>
					IF (CRCPASS <= '0') THEN	-- Test decoder, single CRC + Data bit error (Should not pass)
						led(6) <= '1';
					END IF;
				WHEN others =>
					led(7) <= "1";	-- Indicates something went wrong 
			END CASE;
		END IF;
	END IF;
END PROCESS;
end Behavioral;

