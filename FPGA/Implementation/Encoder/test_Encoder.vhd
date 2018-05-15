LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
 
ENTITY test_Encoder IS
END test_Encoder;
 
ARCHITECTURE behavior OF test_Encoder IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT Encoder
    PORT(
         CLK : IN  std_logic;
			ard_rdy : IN std_logic;
         input : IN  std_logic;
			output : OUT  std_logic
        );
    END COMPONENT;
    
   --Inputs
   signal CLK : std_logic := '0';
   signal input : std_logic := '1';
	signal ard_rdy : std_logic := '0';

 	--Outputs
   signal output : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 32 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Encoder PORT MAP (
          CLK => CLK,
          input => input,
			 ard_rdy => ard_rdy,
          output => output
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
		input <= '1';
		ard_rdy <= '0';
      -- insert stimulus here 
		wait for 25000 ns;
		input <= '0';	-- h'E3		-- Comment these lines to simulate an uneven amount of bytes
		wait for CLK_period*278;	--
		input <= '1';					--
		wait for CLK_period*278;	--
		wait for CLK_period*278;	--
		input <= '0';					--
		wait for CLK_period*278;	--
		wait for CLK_period*278;	--
		wait for CLK_period*278;	--
		input <= '1';					--
		wait for CLK_period*278;	--
		wait for CLK_period*278;	--
		wait for CLK_period*278;	--
		wait for CLK_period*278;	--
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'E3
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		
		-------------
		input <= '0';	-- h'FF
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		
		input <= '0';	-- h'D9
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		wait for CLK_period*278;
		input <= '1';
		wait for CLK_period*278;
		wait for CLK_period*278;
		wait for CLK_period*278;
		input <= '0';
		--
		wait for 30864 ns;	-- Ready to transmit
		--
		ard_rdy <= '1'; -- Pin is kept 'high' during simulation
      wait;
   end process;
END;
