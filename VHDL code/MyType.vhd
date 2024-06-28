library IEEE;
use IEEE.std_logic_1164.all;

package MyType is
	CONSTANT NB_OCTETS : integer := 51;	-- trame de 1 octets
	Type t_array_byte is array (0 to NB_OCTETS-1) of std_logic_vector(7 downto 0);
	CONSTANT c_nb_clk_per_bit : integer := 2604;
	type r_STATE is (IDLE, LASER_PREHEAT, ACQUISITION);
	type r_STATE_TRIG_MOTOR is (IDLE, TRIG);
end package MyType;