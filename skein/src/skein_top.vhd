-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

-- Possible generics values: 
--		HS = {HASH_SIZE_256, HASH_SIZE_512} 
--		UF = {1, 4, 8}	-- unrolling factor
--		ADDERTYPE = {SCCA_BASED, CLA_BASED, FCCA_BASED}
--		VERSION = {SHA3_ROUND2, SHA3_ROUND2}
-- Note : All combinations are allowed.

-- Extra generic(s) :
-- 		w = {2^x} where x can be any reasonable number. By default, x is 6
-- Note : Input and output test vectors must correspond to the size of w

library ieee;
use ieee.std_logic_1164.all;
use work.sha3_skein_package.all;
use work.sha3_pkg.all;

entity skein_top is		
	generic (	
		VERSION : integer := SHA3_ROUND3;
		ADDERTYPE : integer := SCCA_BASED; 
		W : integer := 64;				  
		UF : integer := 4;
		HS : integer := HASH_SIZE_512		
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
		din		: in std_logic_vector(w-1 downto 0);
		dout	: out std_logic_vector(w-1 downto 0)
	);	   
end skein_top;


architecture structure of skein_top is   
	-- padding unit   
	signal comp_rem_e0, comp_lb_e0, en_lb, clr_lb : std_logic;
	signal spos : std_logic;
	-- tweak
	signal tw_bit_pad, tw_final, tw_first : std_logic;
	signal tw_type : std_logic_vector(5 downto 0);
	-- fsm1
	signal ein, lc, ec: std_logic;
	signal zc0, zcRemNon0, zcRem1, padded, clr_rem : std_logic;	
	signal dth, eth : std_logic;
	-- fsm2
	signal er, etweak, lo, sf : std_logic;
	signal slast, snb, sfinal : std_logic;	 
	signal rsel : std_logic_vector(2 downto 0);
	-- fsm3
	signal eout : std_logic;
									 	
begin		 
	control_gen : entity work.skein_control(struct)  
		generic map ( w=>w,  h => HS, round_unrolled => UF )
		port map (
		rst => rst, clk => clk, 
		src_ready => src_ready, src_read => src_read, dst_ready => dst_ready, dst_write => dst_write,	  
			zc0 => zc0, zcRemNon0 => zcRemNon0, zcRem1 => zcRem1, padded => padded, clr_rem => clr_rem, 
			tw_bit_pad => tw_bit_pad, tw_final => tw_final, tw_first => tw_first, tw_type => tw_type,
		final_segment => din(w-1), ein => ein, ec => ec, lc => lc, dth => dth, eth => eth, etweak => etweak,
		er => er, lo => lo, sf => sf, sfinal => sfinal, snb => snb,  slast => slast, rsel => rsel,
		eout => eout,
        -- pad
        comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,	spos => spos
	);			
	
	datapath_gen : entity work.skein_datapath(struct) 
		generic map ( version => VERSION, adder_type => ADDERTYPE, w => w, h => HS, round_unrolled => UF )
		port map (
		rst => rst, clk => clk, din => din, dout => dout,
		ein => ein, ec => ec, lc => lc, dth => dth, eth => eth, etweak => etweak,
			zc0 => zc0, zcRemNon0 => zcRemNon0, zcRem1 => zcRem1, padded => padded, clr_rem => clr_rem, 
			tw_bit_pad => tw_bit_pad, tw_final => tw_final, tw_first => tw_first, tw_type => tw_type,
		er => er, lo => lo, sf => sf, sfinal => sfinal,  snb => snb,  slast => slast, rsel => rsel,
		eout => eout,
        -- pad
        comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,	spos => spos
	);

end structure;
	
	