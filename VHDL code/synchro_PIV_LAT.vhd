-- Set Generic g_CLKS_PER_BIT as follows:
-- g_CLKS_PER_BIT = (Frequency of i_Clk)/(Frequency of UART)
-- Example: 50 MHz Clock, 230400 baud UART
-- (50000000)/(230400) = 217

	-- trame RS232:
	-- acquisition mode : 1 octet
	-- number of frame : 2 octets
	-- time between pulses us: 2 octets
	-- exposition time PIV us: 2 octets
	-- exposition time LAT us: 2 octets
	-- delta time expo-pulses us: 1 octet
	-- FL pulse duration us: 1 octet
	-- QS pulse duration us: 1 octet
	-- number_pulse_heat_laser: 1 octet
	-- number pulse PIV skip frame: 1 octet
	-- number pulse LAT skip frame: 1 octet
	-- total: 15 octets
	
	
	library IEEE;
   use IEEE.std_logic_1164.all;
	--use IEEE.Std_Logic_Arith.all;
   use IEEE.numeric_std.all;

	library work;
	use work.MyType.all;
	
	ENTITY	synchro_piv_lat IS
	
		PORT (
			i_RTS					: 	in			std_logic;
			i_50M       	   : 	in			std_logic;
			i_RX        	   : 	in			std_logic;
			o_TX					: 	out		std_logic;
			o_FL1					: 	out 		std_logic;
			o_FL1_LED			: 	out 		std_logic;
			o_FL2					: 	out 		std_logic;
			o_FL2_LED			: 	out 		std_logic;
			o_QS1					: 	out 		std_logic;
			o_QS1_LED			: 	out 		std_logic;
			o_QS2					: 	out 		std_logic;
			o_QS2_LED			: 	out 		std_logic;
			o_LED_PANNEL		: 	out 		std_logic;
			o_LED_PANNEL_LED	: 	out 		std_logic;
			o_TRIG_CAM1			: 	out 		std_logic;
			o_TRIG_CAM1_LED	: 	out 		std_logic;
			o_TRIG_CAM2			: 	out 		std_logic;
			o_TRIG_CAM2_LED	: 	out 		std_logic;
			o_led_RW				: 	out 		std_logic;
			o_led_RTS			:	out		std_logic;
			o_change_SM_STATE	: 	out 		std_logic;
			o_TRIG_MOT			:	out		std_logic;
			o_pulse_MOT			:	out		std_logic;
			o_state				:	out		std_logic_vector(1 downto 0)

			);
			
			
	
	END synchro_piv_lat;
	
	ARCHITECTURE	arch_synchro_piv_lat of synchro_piv_lat	IS
	
		--SIGNAL r_time_between_pulses_us					:unsigned (15 downto 0)	:= '0'; -- 1 à 65532 µs
		--SIGNAL r_exposure_time_piv_frame_us				:unsigned (15 downto 0)	:= '0'; -- 1 à 65532 µs
		--SIGNAL r_exposure_time_LED_frame_us				:unsigned (15 downto 0)	:= '0'; -- 1 à 65532 µs
		--SIGNAL r_delta_exposure_pulse_us					:unsigned (7 downto 0)	:= '0'; -- 1 à 256 µs
		--SIGNAL r_FL_pulse_duration_us						:unsigned (7 downto 0)	:= '0'; -- 1 à 256 µs
		--SIGNAL r_QS_pulse_duration_us						:unsigned (7 downto 0)	:= '0'; -- 1 à 256 µs
		
		SIGNAL SM_state										:r_STATE := IDLE;
		SIGNAL SM_state_trig_mot							:r_STATE_TRIG_MOTOR := IDLE;
		SIGNAL r_new_command									:std_logic := '0';
		SIGNAL r_previous_SM_STATE							:r_STATE := IDLE;
		SIGNAL w_count_divider								:UNSIGNED (7 downto 0):= to_unsigned(0, 8);
		SIGNAL w_clock_1M										:std_logic := '0';
		SIGNAL w_time_us										:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- temps en µs
		SIGNAL w_time_s										:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24);	-- temps en seconde
		SIGNAL s_read_buffer									:T_array_byte;
		SIGNAL w_data_received_status						:std_logic := '0';
		SIGNAL r_trig_mot										:std_logic :='0';
		SIGNAL w_elapsed_time_trig_mot					:UNSIGNED (31 downto 0) := to_unsigned(0, 32);
		
		SIGNAL r_acquisition_mode							:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 0: STOP, 1: PIV, 2: PIV+LAT, 3: LAT
		SIGNAL r_number_of_period							:UNSIGNED (15 downto 0)	:= to_unsigned(0, 16); -- 0:continuous, else: finite
		SIGNAL r_number_of_period_executed				:UNSIGNED (15 downto 0)	:= to_unsigned(0, 16); 	
		SIGNAL r_start_expo_piv1_us						:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_expo_piv1_us							:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		
		SIGNAL r_start_expo_piv2_us						:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_expo_piv2_us							:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		
		SIGNAL r_start_expo_lat_us							:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_expo_lat_us							:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		
		SIGNAL r_start_FL1_us								:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_FL1_us									:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_start_QS1_us								:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_QS1_us									:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		
		SIGNAL r_start_FL2_us								:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_FL2_us									:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_start_QS2_us								:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		SIGNAL r_stop_QS2_us									:UNSIGNED (23 downto 0)	:= to_unsigned(0, 24); -- 1 à 16 777 215 µs
		
		SIGNAL w_i_period_us									:UNSIGNED (23 downto 0) := to_unsigned(0,24); -- 1 à 16 777 215 µs
		
		SIGNAL r_number_pulse_heat_laser					:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 1 à 256 frames
		SIGNAL r_PIV_skip_frames							:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 1 à 256 frames
		SIGNAL r_LAT_skip_frames							:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 1 à 256 frames
		
		SIGNAL r_number_pulse_heat_laser_executed		:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 1 à 256 frames
		SIGNAL r_PIV_skip_frames_executed				:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 1 à 256 frames
		SIGNAL r_LAT_skip_frames_executed				:UNSIGNED (7 downto 0)	:= to_unsigned(0, 8); -- 1 à 256 frames
		
		COMPONENT RS232dyna IS
	
			port(
				i_CLR				: in 	std_logic;
				i_50M          : in  std_logic;
				i_RX           : in  std_logic;
				o_TX				: out std_logic;
				o_RCV_bytes		: out t_array_byte;
				o_LEDR0			: buffer std_logic;
				o_data_received_status	: out std_logic
				);

		END COMPONENT;
		
	BEGIN
		o_led_RTS <= i_rTS;
		--o_pulse_MOT <= NOT(r_trig_mot);
	
		--o_TRIG_MOT <= '1' when r_number_pulse_heat_laser = to_unsigned(0,8) else '0';
		
		with SM_state select o_state <=
			"11" WHEN IDLE,
			"10" WHEN LASER_PREHEAT,
			"01" WHEN ACQUISITION,
			"00" WHEN OTHERS;
			
		--------------------------------------------------------------
		------------ proces to generate a 1MHz clock------------------
		--------------------------------------------------------------
		p_clock1M: PROCESS (i_50M) is 
		BEGIN
			IF (SM_state = IDLE) THEN
				w_count_divider <= "00000000";
				w_clock_1M <= '0';
			ELSIF (SM_state = ACQUISITION OR SM_state = LASER_PREHEAT) AND (rising_edge(i_50M)) THEN
				IF (w_count_divider = 49) THEN
					w_count_divider <= "00000000";
					w_clock_1M <= '1';
				ELSE
					w_count_divider <= w_count_divider + 1;
					w_clock_1M <= '0';
				END IF;
			END IF;
		END PROCESS p_clock1M;
		
		
		-------------------------------------------------------------------------------
		------------ process to generate the time signal and period count -------------
		-------------------------------------------------------------------------------
		--p_time: PROCESS (w_clock_1M, SM_state) is
		p_time: PROCESS (w_clock_1M) is 
		BEGIN
				CASE SM_state IS
					WHEN IDLE =>
						w_time_us <= to_unsigned(0, 24);
						r_number_of_period_executed <= to_unsigned(0, 16);
						r_number_pulse_heat_laser_executed <= to_unsigned(0, 8);
						
					WHEN OTHERS =>
						IF rising_edge(w_clock_1M) THEN
							IF (w_time_us >= w_i_period_us) THEN
								w_time_us <= to_unsigned(0, 24);
									IF SM_state = LASER_PREHEAT THEN
										r_number_pulse_heat_laser_executed <= r_number_pulse_heat_laser_executed + 1;
									ELSIF SM_state = ACQUISITION THEN
										r_number_of_period_executed <= r_number_of_period_executed + 1;
									END IF;
							ELSE
								w_time_us <= w_time_us + 1;
							END IF;
						END IF;
				END CASE;
		END PROCESS p_time;
		
		--------------------------------------------------------------
		------------ proces to generate a motor trigger --------------
		--------------------------------------------------------------
		p_trigger_motor: PROCESS (i_50M) is --on compte jusqu'à 1000 pour avoir 1ms
		BEGIN
			IF rising_edge(i_50M) THEN
				CASE SM_state_trig_mot IS
					WHEN IDLE =>
						
						w_elapsed_time_trig_mot <= to_unsigned(0, 32);
						IF (r_trig_mot = '1') THEN
							SM_state_trig_mot <= TRIG;
							o_TRIG_MOT <= '0'; --la sortie est inversée ('0' à l'état haut)
						ELSE
							SM_state_trig_mot <= IDLE;
							o_TRIG_MOT <= '1'; --la sortie est inversée ('0' à l'état haut)
						END IF;
						
					WHEN TRIG =>
						w_elapsed_time_trig_mot <= w_elapsed_time_trig_mot + to_unsigned(1, 32);

						IF w_elapsed_time_trig_mot >= to_unsigned(50000, 32) THEN
							SM_state_trig_mot <= IDLE;
							o_TRIG_MOT <= '1';
						ELSE
							SM_state_trig_mot <= TRIG;
							o_TRIG_MOT <= '0';
						END IF;
				END CASE;
			END IF;
		END PROCESS p_trigger_motor;
		
		-----------------------------------------------------------------------------
		------------ process UPDATE COMMAND -----------------------------------------
		-----------------------------------------------------------------------------
		
		p_update_command: PROCESS (i_50M) IS
		BEGIN
		
			if rising_edge(i_50M) THEN
				IF w_data_received_status = '1' THEN 
			
					r_acquisition_mode <= unsigned(s_read_buffer(0));
					r_new_command <= '1';
				
					IF SM_state = IDLE THEN
							
							r_number_of_period(15 downto 8) <= unsigned(s_read_buffer(1));
							r_number_of_period(7 downto 0) <= unsigned(s_read_buffer(2));
							
							r_start_expo_piv1_us(23 downto 16) <= unsigned(s_read_buffer(3));
							r_start_expo_piv1_us(15 downto 8) <= unsigned(s_read_buffer(4));
							r_start_expo_piv1_us(7 downto 0) <= unsigned(s_read_buffer(5));
							
							r_stop_expo_piv1_us(23 downto 16) <= unsigned(s_read_buffer(6));
							r_stop_expo_piv1_us(15 downto 8) <= unsigned(s_read_buffer(7));
							r_stop_expo_piv1_us(7 downto 0) <= unsigned(s_read_buffer(8));
							
							r_start_expo_piv2_us(23 downto 16) <= unsigned(s_read_buffer(9));
							r_start_expo_piv2_us(15 downto 8) <= unsigned(s_read_buffer(10));
							r_start_expo_piv2_us(7 downto 0) <= unsigned(s_read_buffer(11));
							
							r_stop_expo_piv2_us(23 downto 16) <= unsigned(s_read_buffer(12));
							r_stop_expo_piv2_us(15 downto 8) <= unsigned(s_read_buffer(13));
							r_stop_expo_piv2_us(7 downto 0) <= unsigned(s_read_buffer(14));
							
							r_start_expo_lat_us(23 downto 16) <= unsigned(s_read_buffer(15));
							r_start_expo_lat_us(15 downto 8) <= unsigned(s_read_buffer(16));
							r_start_expo_lat_us(7 downto 0) <= unsigned(s_read_buffer(17));
							
							r_stop_expo_lat_us(23 downto 16) <= unsigned(s_read_buffer(18));
							r_stop_expo_lat_us(15 downto 8) <= unsigned(s_read_buffer(19));
							r_stop_expo_lat_us(7 downto 0) <= unsigned(s_read_buffer(20));
							
							r_start_FL1_us(23 downto 16) <= unsigned(s_read_buffer(21));
							r_start_FL1_us(15 downto 8) <= unsigned(s_read_buffer(22));
							r_start_FL1_us(7 downto 0) <= unsigned(s_read_buffer(23));
							
							r_stop_FL1_us(23 downto 16) <= unsigned(s_read_buffer(24));
							r_stop_FL1_us(15 downto 8) <= unsigned(s_read_buffer(25));
							r_stop_FL1_us(7 downto 0) <= unsigned(s_read_buffer(26));
							
							r_start_QS1_us(23 downto 16) <= unsigned(s_read_buffer(27));
							r_start_QS1_us(15 downto 8) <= unsigned(s_read_buffer(28));
							r_start_QS1_us(7 downto 0) <= unsigned(s_read_buffer(29));
							
							r_stop_QS1_us(23 downto 16) <= unsigned(s_read_buffer(30));
							r_stop_QS1_us(15 downto 8) <= unsigned(s_read_buffer(31));
							r_stop_QS1_us(7 downto 0) <= unsigned(s_read_buffer(32));
							
							r_start_FL2_us(23 downto 16) <= unsigned(s_read_buffer(33));
							r_start_FL2_us(15 downto 8) <= unsigned(s_read_buffer(34));
							r_start_FL2_us(7 downto 0) <= unsigned(s_read_buffer(35));
							
							r_stop_FL2_us(23 downto 16) <= unsigned(s_read_buffer(36));
							r_stop_FL2_us(15 downto 8) <= unsigned(s_read_buffer(37));
							r_stop_FL2_us(7 downto 0) <= unsigned(s_read_buffer(38));
							
							r_start_QS2_us(23 downto 16) <= unsigned(s_read_buffer(39));
							r_start_QS2_us(15 downto 8) <= unsigned(s_read_buffer(40));
							r_start_QS2_us(7 downto 0) <= unsigned(s_read_buffer(41));
							
							r_stop_QS2_us(23 downto 16) <= unsigned(s_read_buffer(42));
							r_stop_QS2_us(15 downto 8) <= unsigned(s_read_buffer(43));
							r_stop_QS2_us(7 downto 0) <= unsigned(s_read_buffer(44));
							
							w_i_period_us(23 downto 16) <= unsigned(s_read_buffer(45));
							w_i_period_us(15 downto 8) <= unsigned(s_read_buffer(46));
							w_i_period_us(7 downto 0) <= unsigned(s_read_buffer(47));
							
							r_number_pulse_heat_laser(7 downto 0) <= unsigned(s_read_buffer(48));
							
							r_PIV_skip_frames(7 downto 0) <= unsigned(s_read_buffer(49));
							
							r_LAT_skip_frames(7 downto 0) <= unsigned(s_read_buffer(50));
							
					END IF;	
				END IF;
				
				IF r_new_command = '1' THEN
					r_new_command <= '0';
				END IF;		
			END IF;
			
		END PROCESS p_update_command;
		
		-----------------------------------------------------------------------------
		------------ process STATE MACHINE ------------------------------------------
		-----------------------------------------------------------------------------
		
		p_state_machine: PROCESS (i_50M) IS
		BEGIN
			IF rising_edge(i_50M) THEN
				CASE SM_state IS
				
					WHEN IDLE =>
						IF (r_new_command = '1') THEN
							CASE r_acquisition_mode IS
								WHEN to_unsigned(0,8) => -- STOP
									SM_state <= IDLE;
								WHEN to_unsigned(3,8) => -- LAT
									SM_state <= ACQUISITION;
								WHEN OTHERS => -- PIV ou PIV+LAT
									IF (r_number_pulse_heat_laser = to_unsigned(0, 8)) THEN
										SM_state <= ACQUISITION;
									ELSE
										SM_state <= LASER_PREHEAT;
									END IF;
								END CASE;
							END IF;

					WHEN LASER_PREHEAT =>
						IF ((r_new_command = '1') AND (r_acquisition_mode = to_unsigned(0,8)))  THEN -- STOP
							SM_state <= IDLE;
						ELSIF (r_number_pulse_heat_laser_executed >= r_number_pulse_heat_laser) THEN 
							SM_state <= ACQUISITION;
						ELSE
							SM_state <= LASER_PREHEAT;
						END IF;
						
					WHEN ACQUISITION =>
						IF (((r_new_command = '1') AND (r_acquisition_mode = to_unsigned(0,8))) OR 
							((r_number_of_period/= to_unsigned(0, 8)) AND (r_number_of_period_executed >= r_number_of_period))) THEN -- STOP
							SM_state <= IDLE;
						ELSE SM_state <= ACQUISITION;
						END IF;
				END CASE;
				
				r_previous_SM_STATE <= SM_state;
				
				IF r_previous_SM_STATE = SM_state THEN --pas de changement d'état
					o_change_SM_STATE <= '0';
					r_trig_mot <= '0';
					o_pulse_MOT<='1';
					
				ELSE --changement d'état
					o_change_SM_STATE <= '1';
						IF (SM_state = ACQUISITION) THEN --changemeny d'état vers ACQUISITION
							r_trig_mot <= '1';
							o_pulse_MOT<='0';
						ELSE
							r_trig_mot <= '0';
							o_pulse_MOT<='1';
						END IF;
				END IF;
						
			END IF;
			
		END PROCESS p_state_machine;
		
		-----------------------------------------------------------------------------
		------------  PULSE GENERATION ----------------------------------------------
		-----------------------------------------------------------------------------
		
		p_pulse_generation: PROCESS (i_50M) IS
		BEGIN
			
			IF rising_edge(i_50M) THEN

				CASE SM_state IS
				
					WHEN IDLE =>

						r_PIV_skip_frames_executed <= to_unsigned(0, 8);
						r_LAT_skip_frames_executed <= to_unsigned(0, 8);
						o_FL1 <= '1';
						o_FL2 <= '1';
						o_QS1 <= '1';
						o_QS2 <= '1';
						o_LED_PANNEL <= '1';
						o_TRIG_CAM1 <= '1';
						o_TRIG_CAM2 <= '1';
						o_FL1_LED <= '1';
						o_FL2_LED <= '1';
						o_QS1_LED <= '1';
						o_QS2_LED <= '1';
						o_LED_PANNEL_LED <= '1';
						o_TRIG_CAM1_LED <= '1';
						o_TRIG_CAM2_LED <= '1';
						
					WHEN LASER_PREHEAT =>
						
						IF (w_time_us >= r_start_FL1_us) AND (w_time_us <= r_stop_FL1_us) THEN
							o_FL1 <= '0';
							o_FL1_LED <= '0';
						ELSE
							o_FL1 <= '1';
							o_FL1_LED <= '1';
						END IF;
					
						IF (w_time_us >= r_start_FL2_us) AND (w_time_us <= r_stop_FL2_us) THEN
							o_FL2 <= '0';
							o_FL2_LED <= '0';
						ELSE
							o_FL2 <= '1';
							o_FL2_LED <= '1';
						END IF;
					
						IF (w_time_us >= r_start_QS1_us) AND (w_time_us <= r_stop_qS1_us) THEN
							o_QS1 <= '0';
							o_QS1_LED <= '0';
						ELSE
							o_QS1 <= '1';
							o_QS1_LED <= '1';
						END IF;
						
						IF (w_time_us >= r_start_QS2_us) AND (w_time_us <= r_stop_qS2_us) THEN
							o_QS2 <= '0';
							o_QS2_LED <= '0';
						ELSE
							o_QS2 <= '1';
							o_QS2_LED <= '1';
						END IF;
					
					WHEN ACQUISITION =>
					
						IF (
							(w_time_us >= r_start_expo_lat_us AND w_time_us <= r_stop_expo_lat_us)
							AND (r_LAT_skip_frames = 0 OR r_number_of_period_executed mod (r_LAT_skip_frames + 1)  = 0) 
							AND (r_acquisition_mode = to_unsigned(2,8) OR r_acquisition_mode = to_unsigned(3,8))
							)
							OR
							(
							((w_time_us >= r_start_expo_piv1_us AND w_time_us <= r_stop_expo_piv1_us) OR (w_time_us >= r_start_expo_piv2_us AND w_time_us <= r_stop_expo_piv2_us))
								AND (r_PIV_skip_frames  = 0 OR r_number_of_period_executed mod (r_PIV_skip_frames + 1)  = 0)
								AND (r_acquisition_mode = to_unsigned(1,8) OR r_acquisition_mode = to_unsigned(2,8))
							) THEN
								o_TRIG_CAM1 <= '0';
								o_TRIG_CAM1_LED <= '0';
							ELSE
								o_TRIG_CAM1 <= '1';
								o_TRIG_CAM1_LED <= '1';
						END IF;
					
						IF (w_time_us >= r_start_expo_lat_us) AND (w_time_us <= r_stop_expo_lat_us) AND
							(r_LAT_skip_frames = 0 OR r_number_of_period_executed mod (r_LAT_skip_frames + 1)  = 0) AND
								( r_acquisition_mode = to_unsigned(2,8) OR r_acquisition_mode = to_unsigned(3,8))  THEN
								o_LED_PANNEL <= '0';
								o_LED_PANNEL_LED <= '0';
						ELSE
							o_LED_PANNEL <= '1';
							o_LED_PANNEL_LED <= '1';
						END IF;
						
						IF (w_time_us >= r_start_FL1_us) AND (w_time_us <= r_stop_FL1_us) 
						AND (r_acquisition_mode = to_unsigned(1,8) OR r_acquisition_mode = to_unsigned(2,8)) THEN
							o_FL1 <= '0';
							o_FL1_LED <= '0';
						ELSE
							o_FL1 <= '1';
							o_FL1_LED <= '1';
						END IF;
							
						IF (w_time_us >= r_start_FL2_us) AND (w_time_us <= r_stop_FL2_us)
						AND (r_acquisition_mode = to_unsigned(1,8) OR r_acquisition_mode = to_unsigned(2,8)) THEN
							o_FL2 <= '0';
							o_FL2_LED <= '0';
						ELSE
							o_FL2 <= '1';
							o_FL2_LED <= '1';
						END IF;
							
						IF (r_PIV_skip_frames  = 0 OR r_number_of_period_executed mod (r_PIV_skip_frames + 1)  = 0)
						AND (r_acquisition_mode = to_unsigned(1,8) OR r_acquisition_mode = to_unsigned(2,8)) THEN
							
							IF (w_time_us >= r_start_QS1_us) AND (w_time_us <= r_stop_qS1_us) THEN
								o_QS1 <= '0';
								o_QS1_LED <= '0';
							ELSE
								o_QS1 <= '1';
								o_QS1_LED <= '1';
							END IF;
							
							IF (w_time_us >= r_start_QS2_us) AND (w_time_us <= r_stop_qS2_us) THEN
								o_QS2 <= '0';
								o_QS2_LED <= '0';
							ELSE 
								o_QS2 <= '1';
								o_QS2_LED <= '1';
							END IF;			
						END IF;

					END CASE;
			END IF;
		END PROCESS p_pulse_generation;

		port_Rs232_dyna: RS232dyna
		PORT MAP(i_RTS, i_50M, i_RX, o_TX, s_read_buffer, o_led_RW, w_data_received_status);
	
	END arch_synchro_piv_lat;

	
	