-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.sha3_pkg.all;
use work.groestl_pkg.all;

-- Groestl fsm2 is responsible for Groestl computation processing
-- Possible generics values:
-- hs = {HASH_SIZE_256, HASH_SIZE_512}

entity groestl_fsm2_pq_parallel is
	generic (hs : integer:=HASH_SIZE_256);
	port (
		clk 					: in std_logic;
		rst 					: in std_logic;

		final					: out std_logic;
		init1					: out std_logic;
		init2					: out std_logic;
		init3					: out std_logic;
		load_ctr				: out std_logic;
		wr_ctr					: out std_logic;
		wr_result				: out std_logic;
		wr_state				: out std_logic;
		lo						: out std_logic;

		block_ready_clr 		: out std_logic;
		msg_end_clr 			: out std_logic;
		block_ready				: in std_logic;
		msg_end 				: in std_logic;
		output_write_set 		: out std_logic;
		output_busy_set  		: out std_logic;
		output_busy		 		: in  std_logic);
end groestl_fsm2_pq_parallel;


architecture beh of groestl_fsm2_pq_parallel is
	function get_roundnr ( hs : integer ) return integer is
	begin
		if hs = 256 then
			return 10;
		elsif hs = 512 then
			return 14;
		end if;
	end function get_roundnr ;

	constant roundnr 		: integer := get_roundnr(hs);  -- Add an additional round for block finalization
	constant log2roundnr	: integer := log2( roundnr );
	constant log2roundnrzeros : std_logic_vector(log2roundnr-1 downto 0) := (others => '0') ;

	type state_type is ( reset, idle, process_data, process_last_data, finalization, write_output, output_data );
	signal cstate, nstate : state_type;

	signal pc : std_logic_vector(log2roundnr-1 downto 0);
	signal ziroundnr, li, ei : std_logic;
	signal output_data_s : std_logic;

begin
	-- fsm2 counter
	proc_counter_gen : countern generic map ( N => log2roundnr ) port map ( clk => clk, rst => rst, load => li, en => ei, input => log2roundnrzeros, output => pc);
	ziroundnr <= '1' when pc = conv_std_logic_vector(roundnr-1,log2roundnr) else '0';

	-- state process
	cstate_proc : process ( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				cstate <= reset;
			else
				cstate <= nstate;
			end if;
		end if;
	end process;

	nstate_proc : process ( cstate, msg_end, output_busy, block_ready, ziroundnr )
	begin
		case cstate is
			when reset =>
				nstate <= idle;
			when idle =>
				if ( block_ready = '1' and msg_end = '0' ) then
					nstate <= process_data;
				elsif (block_ready = '1' and msg_end = '1') then
					nstate <= process_last_data;
				else
					nstate <= idle;
				end if;
			when process_data =>
				if ( ziroundnr = '0' ) or (ziroundnr = '1' and msg_end = '0' and block_ready = '1') then
					nstate <= process_data;
				elsif (ziroundnr = '1' and msg_end = '1') then
					nstate <= process_last_data;
				else
					nstate <= idle;
				end if;
			when process_last_data =>
				if ( ziroundnr = '0' ) then
					nstate <= process_last_data;
				elsif (ziroundnr = '1') then
					nstate <= finalization;
				else
					nstate <= idle;
				end if;
			when finalization =>
				if ( ziroundnr = '0' ) then
					nstate <= finalization;
				else
					nstate <= write_output;
				end if;

			when write_output =>
				if (output_busy = '1') then
					nstate <= output_data;
				else
					nstate <= idle;
				end if;

			when output_data =>
				if ( output_busy = '1') then
					nstate <= output_data;
				else
					nstate <= idle;
				end if;
		end case;
	end process;


	---- output logic
	output_data_s <= '1' when ((cstate = write_output and output_busy = '0') or
								  (cstate = output_data and output_busy = '0')) else '0';
	output_write_set	<= output_data_s;
	output_busy_set 	<= output_data_s;
	lo					<= output_data_s;


	block_ready_clr		<= '1' when (cstate = idle and block_ready = '1') or
                                    ((cstate = process_data or cstate = process_last_data) and pc = 0 and block_ready = '1')
                            else '0';


	ei <= '1' when ((cstate = idle and block_ready = '1') or
					((cstate = process_data or cstate = process_last_data) and ziroundnr = '0') or
					(cstate = finalization and ziroundnr = '0')) else '0';

	li <=  '1' when  (cstate = reset) or (ziroundnr = '1') else '0';

	final <= '1' when (cstate = finalization ) and (ziroundnr = '1') else '0';
	init1 <= '1' when  (cstate = idle and block_ready = '1') or
						((cstate = process_data or cstate = process_last_data) and pc = 0) or
						(cstate = output_data and output_busy = '0' and block_ready = '1') else '0';
	init2 <= '1' when (cstate = finalization and pc = 0)  else '0';

	init3 <= '1' when (cstate = reset) or (cstate = write_output) or (cstate = output_data) else '0';

	load_ctr <= '1' when (cstate = reset) or ((cstate = process_data or cstate = process_last_data) and ziroundnr = '1') or
						(cstate = finalization and pc=roundnr-1) else '0';

	wr_ctr <= '1' when 	(cstate = idle and block_ready = '1') or
						(cstate = process_data or cstate = process_last_data or cstate = finalization ) else '0';
	wr_result <= '1' when (cstate = reset) or
						((cstate = process_data or cstate = process_last_data) and ( ziroundnr = '1' )) or
						(cstate = finalization and ziroundnr = '1' ) or
						(cstate = write_output and output_busy = '0') or
						(cstate = output_data and output_busy = '0')  else '0';
	wr_state <= '1' when (cstate = idle and block_ready = '1') or
						(cstate = process_data and ziroundnr = '0') or
						((cstate = process_data) and ziroundnr = '1' and ((msg_end = '0' and block_ready = '1') or (msg_end = '1'))) or
						(cstate = process_last_data) or
						(cstate = finalization and ziroundnr = '0') or
						(cstate = finalization and ziroundnr = '1' and output_busy = '0') or
						(cstate = output_data and output_busy = '0') else '0';


	msg_end_clr <= '1' when (cstate = idle and block_ready = '1' and msg_end = '1') or
							(cstate = process_data and block_ready = '1' and msg_end = '1' and ziroundnr = '1') else '0';

end beh;