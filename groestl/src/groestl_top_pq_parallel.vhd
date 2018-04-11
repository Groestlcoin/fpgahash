-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

-- Possible generic values:
--      HS = {HASH_SIZE_256, HASH_SIZE_512},
--      FF = {2, 4, 8}, //(Folding Factor)//
-- 		ROMSTYLE = {DISTRIBUTED, COMBINATIONAL}
--
-- Note: ROMSTYLE refers to the type of rom being used in SBOX implementation
--
-- All combinations are allowed

library ieee;
use ieee.std_logic_1164.all;
use work.sha3_pkg.all;
use work.groestl_pkg.all;


entity groestl_top_pq_parallel is
	generic (
		ROMSTYLE	: integer	:= DISTRIBUTED;
        FF			: integer	:= 2;
		HS 			: integer 	:= HASH_SIZE_256);
	port (
		rst 		: in std_logic;
		clk 		: in std_logic;
		src_ready 	: in std_logic;
		src_read  	: out std_logic;
		dst_ready 	: in std_logic;
		dst_write 	: out std_logic;
		din			: in std_logic_vector(w-1 downto 0);
		dout		: out std_logic_vector(w-1 downto 0)
	);
end groestl_top_pq_parallel;


architecture structure of groestl_top_pq_parallel is
	function get_groest_datasize ( hs : integer ) return integer is
	begin
		if hs = 256 then
			return GROESTL_DATA_SIZE_SMALL;
		elsif hs = 512 then
			return GROESTL_DATA_SIZE_BIG;
		end if;
	end function get_groest_datasize ;

	constant GROESTL_DATA_SIZE : integer := get_groest_datasize( hs );
	signal ein, init1, init2, init3, finalization, wr_state, wr_result	:std_logic;
	signal load_ctr, wr_ctr, sel_out, eout, en_len, en_c : std_logic;
    signal en_ctr, last_block, final_segment	:std_logic;
	signal c	:std_logic_vector(31 downto  log2( GROESTL_DATA_SIZE ));
    signal sel_rd : std_logic_vector(log2(FF)-1 downto 0);
    signal wr_shiftreg : std_logic;
   	-- pad
   	signal spos : std_logic_vector(1 downto 0);
   	signal sel_pad : std_logic;
	signal comp_extra_block, comp_rem_e0, comp_lb_e0, en_lb, clr_lb : std_logic;
	signal rst_ctr : std_logic;
begin



dp_fx2_256 : entity work.groestl_datapath_pq_parallel(basic)
		generic map(n=>GROESTL_DATA_SIZE, HS => HS, rom_style=>ROMSTYLE, FF=>FF)
		port map (clk=>clk, rst=>rst, ein=>ein, en_len => en_len, en_ctr => en_ctr,en_c => en_c,
		init1=>init1, init2=>init2, init3=>init3, finalization=>finalization, 
		wr_state=>wr_state, wr_result=>wr_result, load_ctr=>load_ctr, wr_ctr=>wr_ctr, sel_out=>sel_out,
        sel_rd => sel_rd, wr_shiftreg => wr_shiftreg,
		eout=>eout, c=>c, din=>din, dout=>dout,
		final_segment=>final_segment,
        comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,	comp_extra_block => comp_extra_block,
		spos => spos, sel_pad => sel_pad, rst_ctr => rst_ctr);


ctrl : entity work.groestl_control_pq_parallel(struct)
		generic map(hs=>HS, n=>GROESTL_DATA_SIZE, FF=>FF)
		port map ( clk	=> clk, io_clk =>clk, rst=>rst, ein	=> ein, c=>c, en_ctr => en_ctr, en_len =>en_len,en_c => en_c,
		init1=>init1, init2=>init2, init3=>init3, finalization=>finalization, 
		wr_state=>wr_state, wr_result=>wr_result, load_ctr=>load_ctr, wr_ctr=>wr_ctr, sel_out=>sel_out,
        sel_rd => sel_rd, wr_shiftreg => wr_shiftreg,
		eo =>eout, src_ready=>src_ready, src_read=>src_read, dst_ready=>dst_ready, dst_write=>dst_write,
		final_segment=>final_segment,
        comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,	comp_extra_block => comp_extra_block,
		spos => spos, sel_pad => sel_pad, rst_ctr => rst_ctr);

end structure;

