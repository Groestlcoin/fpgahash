-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

-- Possible generic(s) values: 												 
--		VERSION = {SHA3_ROUND2, SHA3_ROUND3}
--		FF = {1, 2, 4}  Folding Factor (Vertical) %% Default is 2
--		HS = {HASH_SIZE_256, HASH_SIZE_512}
-- 		ADDERTYPE = {SCCA_BASED, CSA_BASED}
--
-- ADDERTYPE describes the type of adders being used in the critical paths. They are :
--      SCCA_BASED      => Standard Carry Chain Addition in FPGA. This is a simple '+' sign.
--      CSA_BASED       => Carry Save Adder.

-- Extra generic(s) :
-- 		w = {2^x} where x can be any reasonable number. By default, x is 6
-- Note : Input and output test vectors must correspond to the size of w

library ieee;
use ieee.std_logic_1164.all; 
use work.sha3_pkg.all;
use work.sha3_blake_package.all;

entity blake_top is		
	generic (		
		VERSION : integer := SHA3_ROUND3;		
		FF : integer := 1;
		HS : integer := HASH_SIZE_256;
		ADDERTYPE : integer := SCCA_BASED;	 	
		W : integer := 64
	); 
	port (		
		-- global
		rst 	: in std_logic;
		clk 	: in std_logic;	
		--fifo
		src_ready : in std_logic;
		src_read  : out std_logic;
		dst_ready : in std_logic;
		dst_write : out std_logic;		
		din		: in std_logic_vector(W-1 downto 0);
		dout	: out std_logic_vector(W-1 downto 0)
	);	   
end blake_top;


architecture structure of blake_top is  
	constant BS : integer := get_b( HS );
	constant IW : integer := get_iw( HS );

	-- fsm1						   
	signal ein, lc, ec, lm: std_logic;
	signal sel_t, dt, eth, etl : std_logic;  
	signal zc1, zc0, comp_rem_mt440 : std_logic;
	-- fsm2
	signal er, em, lo, sf, slr : std_logic;
	signal round : std_logic_vector(3+FF-1 downto 0); 
	-- fsm3
	signal eo : std_logic; 
	-- pad
	signal spos : std_logic_vector(1 downto 0);
	signal comp_rem_e0, comp_lb_e0, en_lb, clr_lb : std_logic;
	signal last_word : std_logic;
	signal sel_pad : std_logic_vector(HS/256-1 downto 0);
									 
begin			   
	control_gen : entity work.blake_control(struct) 
		generic map ( VERSION => VERSION, BS => BS, HS => HS, W => W, FF => FF )
		port map (
		rst => rst, clk => clk, 
		src_ready => src_ready, src_read => src_read, dst_ready => dst_ready, dst_write => dst_write,	  
		final_segment => din(w-1), zc0 => zc0,  ein => ein, ec => ec, zc1 => zc1, 
			lc => lc, dt => dt, eth => eth, etl => etl,  lm => lm, sel_t => sel_t,
		er => er, em => em, lo => lo, sf => sf, slr => slr, round => round,
		eo => eo,	 
		-- pad
		comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, comp_rem_mt440 => comp_rem_mt440, en_lb => en_lb, clr_lb => clr_lb,
		spos => spos, sel_pad => sel_pad, last_word	=> last_word	
	);			
	
	datapath_gen : entity work.blake_datapath(struct) 	
		generic map ( BS => BS, IW => IW, HS => HS, W => W, ADDERTYPE => ADDERTYPE, FF => FF )
		port map (
		rst => rst, clk => clk, din => din, dout => dout, 
		zc0 => zc0,  ein => ein, ec => ec, zc1 => zc1, 
			lc => lc, dt => dt, eth => eth, etl => etl, lm => lm, sel_t => sel_t,
		er => er, em => em, lo => lo, sf => sf, slr => slr, round => round,
		eo => eo,																		
		-- pad
		comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, comp_rem_mt440 => comp_rem_mt440, en_lb => en_lb, clr_lb => clr_lb,
		spos => spos, last_word => last_word, sel_pad => sel_pad	
	);

end structure;
	
	