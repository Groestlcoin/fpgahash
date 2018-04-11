-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

-- Possible generic values: 
--		HS = {HASH_SIZE_256, HASH_SIZE_512} 	
--		UF = {1, 2}	: unrolling factor
--		RCMODE = {ON_THE_FLY (0), MEMORY (1)}

--  RCMODE describes round constant's implementation style. Possible selections are:
--      ON_THE_FLY  : Round constants are generated on the fly
--      MEMORY      : Round constants are stored in the memory

library ieee;
use ieee.std_logic_1164.all; 
use work.sha3_pkg.all;
use work.sha3_jh_package.all;

entity jh_top is		
	generic (			
		HS : integer := 256;
        UF : integer := 1;
		RCMODE : integer := ON_THE_FLY
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
end jh_top;


architecture structure of jh_top is 	
	-- pad
	signal sel_pad, spos : std_logic_vector(1 downto 0);
	signal comp_rem_e0, comp_lb_e0, en_lb, clr_lb : std_logic;
	signal en_size, rst_size : std_logic;
	
	-- fsm1
	signal ein, lc, ec: std_logic;
	signal zc0 : std_logic;
	-- fsm2
	signal er, lo, sf : std_logic;
	signal srdp : std_logic;
	signal round : std_logic_vector(5-(UF-1) downto 0);		 
	signal erf : std_logic;
	-- fsm3
	signal eout : std_logic;
	-- top fsm									 
begin					
	rc_mem_gen : if RCMODE = MEMORY generate
		control_gen : entity work.jh_control_mem(struct)
			generic map ( h => HS, UF => UF )
			port map (
			rst => rst, clk => clk,
			src_ready => src_ready, src_read => src_read, dst_ready => dst_ready, dst_write => dst_write,	  
			zc0 => zc0, final_segment =>  din(63), ein => ein, ec => ec, lc => lc,
			er => er, lo => lo, sf => sf, srdp => srdp, round => round,
			eout => eout,
			comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,
			spos => spos, sel_pad => sel_pad, en_size => en_size, rst_size => rst_size
		);			
		
		datapath_gen : entity work.jh_datapath_mem(struct) 
			generic map ( h => HS, UF => UF )
			port map (
			clk => clk, din => din, dout => dout,
			zc0 => zc0, ein => ein, ec => ec, lc => lc,
			er => er, lo => lo, sf => sf, srdp => srdp, round => round,
			eout => eout,
			-- pad					
			comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb, 
			spos => spos, sel_pad => sel_pad, en_size => en_size, rst_size => rst_size
			
		);		  	   			
	end generate;
	
	rc_otf_gen : if RCMODE = ON_THE_FLY generate
		control_gen : entity work.jh_control_otf(struct)
			generic map ( h => HS, UF => UF )
			port map (
			rst => rst, clk => clk,
			src_ready => src_ready, src_read => src_read, dst_ready => dst_ready, dst_write => dst_write, 	  
			zc0 => zc0, final_segment => din(63), ein => ein, ec => ec, lc => lc,
			er => er, lo => lo, sf => sf, srdp => srdp, erf => erf,
			eout => eout,
			comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,
			spos => spos, sel_pad => sel_pad, en_size => en_size, rst_size => rst_size
		);			
		
		datapath_gen : entity work.jh_datapath_otf(struct) 
			generic map ( h => HS, UF => UF )
			port map (
			clk => clk, din => din, dout => dout,
			zc0 => zc0, ein => ein, ec => ec, lc => lc, 
			er => er, lo => lo, sf => sf, srdp => srdp, erf => erf,
			eout => eout,
            -- pad
			comp_rem_e0 => comp_rem_e0, comp_lb_e0 => comp_lb_e0, en_lb => en_lb, clr_lb => clr_lb,
			spos => spos, sel_pad => sel_pad, en_size => en_size, rst_size => rst_size
		);		  
	end generate;	   	
	
end structure;
	
	