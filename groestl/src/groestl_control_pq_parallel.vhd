-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.sha3_pkg.all;
use work.groestl_pkg.all;

-- Possible generics values:
-- hs = {HASH_SIZE_256, HASH_SIZE_512}

entity groestl_control_pq_parallel is
	generic (
	hs : integer:=HASH_SIZE_256;		   
	FF : integer := 2;
	n : integer := GROESTL_DATA_SIZE_SMALL 	
	);
	port (
		rst						: in std_logic;
		clk						: in std_logic;
		io_clk 					: in std_logic;
		ein						:out std_logic;
		c						: in std_logic_vector(31 downto log2(n));

		en_ctr, en_c			: out std_logic;
		en_len					: out std_logic;

		comp_rem_e0, comp_lb_e0 : in std_logic;
		comp_extra_block		: in std_logic;
        en_lb, clr_lb : out std_logic;
        spos : out std_logic_vector(1 downto 0);
		sel_pad, rst_ctr : out std_logic;
		sel_out					: out std_logic; 
		
		final_segment			: in std_logic;
		finalization			: out std_logic;
		init1					: out std_logic;
		init2					: out std_logic;
		init3					: out std_logic;
		load_ctr				: out std_logic;
		wr_ctr					: out std_logic;
		wr_result				: out std_logic;
		wr_state				: out std_logic;
        sel_rd					: out std_logic_vector(log2(FF)-1 downto 0);
		wr_shiftreg				: out std_logic;

		eo 						: out std_logic;
		src_ready				: in std_logic;
		src_read				: out std_logic;
		dst_ready 				: in std_logic;
		dst_write				: out std_logic);
end groestl_control_pq_parallel;

architecture struct of groestl_control_pq_parallel is
	-- fsm1
	signal block_ready_set, msg_end_set, load_next_block : std_logic;
	-- fsm2
		-- fsm1 communications
	signal block_ready_clr, msg_end_clr : std_logic;
	signal block_ready, msg_end : std_logic;
		-- fsm2 communications
	signal output_write_set, output_busy_set : std_logic;
	signal output_busy : std_logic;

	signal output_write : std_logic;
	signal output_write_clr, output_busy_clr : std_logic;


	-- fsm1 sigs
	signal ein_wire	:std_logic;
	signal en_len_wire, en_ctr_wire :std_logic;
	signal src_read_wire : std_logic;
	signal final_wire, init1_wire, init2_wire, init3_wire : std_logic;
	signal load_ctr_wire, wr_ctr_wire : std_logic;
	signal wr_result_wire, wr_state_wire, lo_wire : std_logic;
    signal wr_shiftreg_wire : std_logic;
	signal sel_rd_wire : std_logic_vector(log2(FF)-1 downto 0);

	signal dst_write_wire, eo_wire, lo_wire_delay : std_logic;
begin

	fsm1_gen : entity work.groestl_fsm1(nocounter)
		generic map (mw=>n)
		port map (clk => io_clk, rst => rst, c => c, en_len => en_len_wire, en_ctr => en_ctr_wire, en_c => en_c,
		ein => ein_wire,load_next_block => load_next_block,
		block_ready_set => block_ready_set, msg_end_set => msg_end_set,
		src_ready => src_ready, src_read => src_read_wire, final_segment=>final_segment,
        comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb, comp_extra_block => comp_extra_block,
		spos => spos, sel_pad => sel_pad, rst_ctr => rst_ctr);


	fsm2_gen : entity work.groestl_fsm2_pq_parallel(beh)
		generic	map (hs=>hs, ff=>ff)
		port map (clk => clk, rst => rst, block_ready => block_ready, msg_end => msg_end, output_busy => output_busy,
		final => final_wire, init1 => init1_wire, init2 => init2_wire, init3 => init3_wire,
		load_ctr => load_ctr_wire, sel_rd => sel_rd_wire, wr_shiftreg => wr_shiftreg_wire,
		wr_ctr => wr_ctr_wire, wr_result => wr_result_wire, wr_state => wr_state_wire, lo => lo_wire,
		block_ready_clr => block_ready_clr, msg_end_clr => msg_end_clr, output_write_set => output_write_set, output_busy_set => output_busy_set
		);

	fsm3_gen : entity work.sha3_fsm3(beh)
		generic map (h=>hs)
		port map (clk => clk, rst => rst, eo => eo_wire,
		output_write => output_write, output_write_clr => output_write_clr, output_busy_clr => output_busy_clr,
		dst_ready => dst_ready, dst_write => dst_write_wire);

	load_next_block <= (not block_ready) or block_ready_clr;

	sr_blk_ready : sr_reg
	port map ( rst => rst, clk => io_clk, set => block_ready_set, clr => block_ready_clr, output => block_ready);

	sr_msg_end : sr_reg
	port map ( rst => rst, clk => io_clk, set => msg_end_set, clr => msg_end_clr, output => msg_end);

	sr_output_write : sr_reg
	port map ( rst => rst, clk => io_clk, set => output_write_set, clr => output_write_clr, output => output_write );

	sr_output_busy : sr_reg
	port map ( rst => rst, clk => io_clk, set => output_busy_set, clr => output_busy_clr, output => output_busy );

	ctrl_reg: process( clk )
	begin
		if rising_edge( clk ) then
			finalization <= final_wire;
			init1 <= init1_wire;
			init2 <= init2_wire;
			init3 <= init3_wire;
			load_ctr <= load_ctr_wire;
			wr_ctr <= wr_ctr_wire;
			wr_result <= wr_result_wire;
			wr_state <= wr_state_wire;
			lo_wire_delay <= lo_wire;
			sel_rd <= sel_rd_wire;
			wr_shiftreg <= wr_shiftreg_wire;
		end if;
	end process;

	ein <= ein_wire;
	en_len <= en_len_wire;
	en_ctr <= en_ctr_wire;
	eo <= eo_wire or lo_wire_delay;
	sel_out <= lo_wire_delay;

	dst_write <= dst_write_wire;
	src_read <= src_read_wire;
end struct;