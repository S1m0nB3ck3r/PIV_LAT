-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 50 MHz Clock, 230400 baud UART
-- (50000000)/(230400) = 217
	
	
	library IEEE;
   use IEEE.std_logic_1164.all;
	use IEEE.Std_Logic_Arith.all;
   use IEEE.numeric_std.all;

	library work;
	use work.MyType.all;
	
	ENTITY	rs232_led IS
	
		PORT (
			i_RTS				: 	in			std_logic;
			i_50M          : 	in			std_logic;
			i_RX           : 	in			std_logic;
			o_TX				: 	out		std_logic;
			o_segments		: 	out 		std_logic_vector(7 downto 0);
			o_led_RW			:	buffer	std_logic
			);
	
	END rs232_led;
	
	ARCHITECTURE	arch_rs232_led of rs232_led	IS
	
		SIGNAL s_read_buffer : T_array_byte;
		
		COMPONENT RS232dyna IS
	
			port(
				i_CLR				: in 	std_logic;
				i_50M          : in  std_logic;
				i_RX           : in  std_logic;
				o_TX				: out std_logic;
				o_RCV_bytes		: out t_array_byte;
				o_LEDR0			: buffer std_logic
				);

		END COMPONENT;
		
	BEGIN
		o_segments <= s_read_buffer(0);

		port_Rs232_dyna: RS232dyna
		PORT MAP(i_RTS, i_50M, i_RX, o_TX, s_read_buffer, o_led_RW);
	
	END arch_rs232_led;
	
	
	