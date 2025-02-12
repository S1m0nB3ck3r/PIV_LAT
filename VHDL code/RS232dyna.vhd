 ----------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
----------------------------------------------------------------------

-- 
-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 50 MHz Clock, 19200 baud UART
-- (50000000)/(19200) = 2604
--
   library IEEE;
   use IEEE.std_logic_1164.all;
	use IEEE.Std_Logic_Arith.all;
--	use IEEE.std_logic_unsigned.all;
   use IEEE.numeric_std.all;
-- use ieee.math_real.all;

	library work;
	use work.MyType.all;
	
   ENTITY RS232dyna is

	port(
		i_CLR					: in 	std_logic;
      i_50M          	: in  std_logic;
      i_RX           	: in  std_logic;
		o_TX					: out std_logic;
		o_RCV_bytes			: out t_array_byte;
		o_LEDR0				: buffer std_logic;
		o_data_received_status	: out std_logic);

   end RS232dyna;
	 
   ARCHITECTURE rtl of RS232dyna is
	
	SIGNAL r_SM_RS232 : integer range 2*NB_OCTETS downto 0 := 0;
	SIGNAL data_received, transmit_data, transmit_active, transmit_done : std_logic;
	SIGNAL byte_received, byte_to_transmit : std_logic_vector(7 downto 0);
	SIGNAL s_array : t_array_byte;
	
-------------------------------------------- Receiver	
	COMPONENT UART_RX
	generic (
		g_CLKS_PER_BIT : integer := 2604;     -- Needs to be set correctly
		c_Nbits : integer := 7					
	);
	port (
		i_Clk       : in  std_logic;
		i_RX_Serial : in  std_logic;
		o_RX_DV     : out std_logic;
		o_RX_Byte   : out std_logic_vector(7 downto 0)
   );
	END COMPONENT;
------------------------------------------- Transmitter
	COMPONENT UART_TX
	generic (
		g_CLKS_PER_BIT : integer := 2604;     -- Needs to be set correctly
		c_Nbits : integer := 7
	);
	port (
		i_Clk       : in  std_logic;
		i_TX_DV     : in  std_logic;
		i_TX_Byte   : in  std_logic_vector(7 downto 0);
		o_TX_Active : out std_logic;
		o_TX_Serial : out std_logic;
		o_TX_Done   : out std_logic
	);
	END COMPONENT;
	
	COMPONENT decodeur7segments
	PORT (
		i_BCD :IN STD_logic_vector(3 downto 0);
		o_LEDS : OUT std_logic_vector(0 TO 7));
	END COMPONENT;


	
	BEGIN
	
	-- Purpose: Control RS232 state machine
		p_RS232 : process (i_50M, i_CLR)
		BEGIN
		if (i_CLR = '1') then
			r_SM_RS232 <= 0;
			transmit_data <= '0';
			o_data_received_status <= '0';
		elsif rising_edge(i_50M) then
			if (r_SM_RS232 >= 0) and (r_SM_RS232 < NB_OCTETS) then	--reception des "NB_OCTETS"
				o_data_received_status <= '0';
				for i in 0 to NB_OCTETS-1 loop
					case r_SM_RS232 is
						when i =>
							if data_received = '1' then 
								s_array(i) <= byte_received;
								r_SM_RS232 <= i+1;
								o_LEDR0 <= not(o_LEDR0);
							end if;
						when others =>
					end case;
				end loop;
			elsif (r_SM_RS232 >= NB_OCTETS) and (r_SM_RS232 < 2*NB_OCTETS) then	--transmission des "NB_OCTETS"
				o_data_received_status <= '1';
				for i in NB_OCTETS to 2*NB_OCTETS-1 loop
					case r_SM_RS232 is
						when i =>
							byte_to_transmit <= s_array(i-NB_OCTETS);
							transmit_data <= '1';
							if transmit_done = '1' then 
								transmit_data <= '0';
								r_SM_RS232 <= i+1;
								o_LEDR0 <= not(o_LEDR0);
							end if;
						when others =>
					end case;
				end loop;
			end if;
			if (r_SM_RS232 = 2*NB_OCTETS) then 
				r_SM_RS232 <= 0;
				o_data_received_status <= '0';
			end if;
		end if;
		END PROCESS p_RS232;
		
		o_RCV_bytes <= s_array;
		
		RX_rs232 : UART_RX
		PORT MAP (i_50M, i_RX, data_received, byte_received);
		
		TX_rs232 : UART_TX
		PORT MAP (i_50M, transmit_data, byte_to_transmit, transmit_active, o_TX, transmit_done);

		--o_state <= conv_std_logic_vector(r_SM_RS232,o_state'length);
		--o_LEDR0 <= i_CLR;
	END rtl;
	
	
