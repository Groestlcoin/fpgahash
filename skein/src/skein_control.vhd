-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; 
use work.sha3_pkg.all;
use work.sha3_skein_package.all;

entity skein_control is		 
	generic ( w: integer := 64; h : integer := HASH_SIZE_256; round_unrolled : integer := 4 );
	port (					
		rst			: in std_logic;
		clk			: in std_logic;
		
		-- datapath signals
			-- tweak
		tw_bit_pad, tw_final, tw_first : out std_logic;
		tw_type : out std_logic_vector(5 downto 0);
			--fsm1
		ein, ec, lc			: out std_logic;		
		zc0, zcRemNon0, zcRem1 : in std_logic;
		padded, final_segment : in std_logic;
		dth, eth, clr_rem : out std_logic;
		
		comp_rem_e0, comp_lb_e0 : in std_logic;
        en_lb, clr_lb : out std_logic;
        spos : out std_logic;
		
			--fsm2
		er, etweak, lo, sf  :  out std_logic;
		slast, snb, sfinal  : out std_logic;
        rsel : out std_logic_vector(2 downto 0);
		
			-- FSM3
		eout 			: out std_logic;		
		
		-- fifo signals
		src_ready	: in std_logic;
		src_read	: out std_logic;
		dst_ready 	: in std_logic;
		dst_write	: out std_logic
	);				 
end skein_control;

architecture struct of skein_control is				   	 
	-- fsm1
	signal block_ready_set, msg_end_set, load_next_block : std_logic;	
	signal tw_bit_pad_en : std_logic;
	-- fsm2						 
		-- fsm1 communications
	signal block_ready_clr, msg_end_clr : std_logic; --out
	signal block_ready, msg_end : std_logic; --in
		-- fsm2 communications
	signal output_write_set, output_busy_set : std_logic; --out
	signal output_busy : std_logic; --in 
	
	signal er_s, sf_s, lo_s, sfinal_s, slast_s : std_logic;
	signal snb_s, etweak_s, dst_write_s : std_logic;
	signal rsel_s : std_logic_vector(2 downto 0);
	
	-- fsm3										
	signal output_write : std_logic; -- in
	signal output_write_clr, output_busy_clr : std_logic; --out	   
	signal eo : std_logic;
	-- sync sigs					
	signal block_ready_clr_sync, msg_end_clr_sync : std_logic;
	signal output_write_set_sync, output_busy_set_sync : std_logic;
begin
	
	fsm1_gen : entity work.skein_fsm1(counter) 
	generic map ( w => w, h => h )	
	port map (
		clk => clk, rst => rst, 
		zc0 => zc0, final_segment => final_segment, ein => ein, ec => ec, lc => lc, dth => dth, eth => eth,
		zcRemNon0 => zcRemNon0, zcRem1 => zcRem1, padded => padded, clr_rem => clr_rem, tw_bit_pad_en => tw_bit_pad_en, 
		load_next_block => load_next_block, block_ready_set => block_ready_set, msg_end_set => msg_end_set, 
		src_ready => src_ready, src_read => src_read,
		comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,	spos => spos
	);	 
	
	fsm2_gen : entity work.skein_fsm2(beh) 
    generic map ( round_unrolled => round_unrolled)	
	port map (
		clk => clk, rst => rst, 
		er => er_s, lo => lo_s, sf => sf_s, sfinal => sfinal_s, snb => snb_s, slast => slast_s, rsel => rsel_s, etweak => etweak_s, 
		block_ready_clr => block_ready_clr, msg_end_clr => msg_end_clr, block_ready => block_ready, msg_end => msg_end,	
		output_write_set => output_write_set, output_busy_set => output_busy_set, output_busy => output_busy
	); 
	
	fsm3_gen : entity work.sha3_fsm3(beh)
	generic map ( w => w, h => h)
	port map (
		clk => clk, rst => rst, 
		eo => eo, 
		output_write => output_write, output_write_clr => output_write_clr, output_busy_clr => output_busy_clr,
		dst_ready => dst_ready, dst_write => dst_write_s
	);	    			
	
	tw_type <= TW_OUT_CONS when sfinal_s = '1' else TW_MSG_CONS;
	tw_final  <= (slast_s or sfinal_s);
	tw_first  <= (sf_s or sfinal_s);
	tw_bit_pad <= tw_bit_pad_en and slast_s;
	
	er <= er_s;
	etweak <= etweak_s;
	rsel <= rsel_s;
	snb <= snb_s;
	sf <= sf_s;
	sfinal <= sfinal_s;
	slast <= slast_s;	
	eout <= eo or lo_s;	
	lo <= lo_s;
	dst_write <= dst_write_s;
	
	load_next_block <= (not block_ready);
	block_ready_clr_sync 	<= block_ready_clr;	 
	msg_end_clr_sync 		<= msg_end_clr;
	output_write_set_sync 	<= output_write_set;
	output_busy_set_sync 	<= output_busy_set;	
	
	sr_blk_ready : sr_reg 
	port map ( rst => rst, clk => clk, set => block_ready_set, clr => block_ready_clr_sync, output => block_ready);
	
	sr_msg_end : sr_reg 
	port map ( rst => rst, clk => clk, set => msg_end_set, clr => msg_end_clr_sync, output => msg_end);
	
	sr_output_write : sr_reg 
	port map ( rst => rst, clk => clk, set => output_write_set_sync, clr => output_write_clr, output => output_write );
	
	sr_output_busy : sr_reg  
	port map ( rst => rst, clk => clk, set => output_busy_set_sync, clr => output_busy_clr, output => output_busy );

end struct;