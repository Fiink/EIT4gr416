LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY test_CRC_Decoder IS
END test_CRC_Decoder;
 
ARCHITECTURE behavior OF test_CRC_Decoder IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT CRC_Decoder
    PORT(
         CLK : IN  std_logic;
         input : IN  std_logic_vector(31 downto 0);
         output : OUT  std_logic_vector(15 downto 0);
         ResetPin : IN  std_logic;
         CRCpass : OUT  std_logic;
         ready : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
	signal input : std_logic_vector(31 downto 0) := x"e3f388ac";
   signal ResetPin : std_logic := '0';

 	--Outputs
   signal output : std_logic_vector(15 downto 0);
   signal CRCpass : std_logic;
   signal ready : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 32 ns;
 
BEGIN
	-- Instantiate the Unit Under Test (UUT)  
   uut: CRC_Decoder PORT MAP (
          CLK => CLK,
          input => input,
          output => output,
          ResetPin => ResetPin,
          CRCpass => CRCpass,
          ready => ready
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin			
      -- hold reset state for 100 ns.
      wait for 100 ns;	
		--ResetPin <= '1';
      wait;
   end process;

END;
