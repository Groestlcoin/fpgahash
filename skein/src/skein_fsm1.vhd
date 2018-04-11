-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use ieee.std_logic_1164.all;			
use ieee.std_logic_unsigned.all; 
use ieee.std_logic_arith.all;
use work.sha3_skein_package.all;
use work.sha3_pkg.all;

entity skein_fsm1 is 
	generic ( w : integer := 64; h : integer := 256 );
	port (
	clk : in std_logic;
	rst : in std_logic;		
	
	-- datapath sigs		
	final_segment : in std_logic;
	zc0, zcRemNon0, zcRem1,padded	: in std_logic;
	tw_bit_pad_en, clr_rem : out std_logic;
	ein, lc, ec : out std_logic;
	dth, eth  : out std_logic;				 
	
	-- pad
	comp_rem_e0, comp_lb_e0 : in std_logic;
    en_lb, clr_lb : out std_logic; 		  
	spos : out std_logic;

	-- Control communication
	load_next_block	: in std_logic;
	block_ready_set : out std_logic;
	msg_end_set : out std_logic;  	
	
	-- FIFO communication
	src_ready : in std_logic;
	src_read    : out std_logic	
	);
end skein_fsm1;

architecture counter of skein_fsm1 is
	constant b 				: integer := 512;
	constant mw				: integer := b;		-- message width	
	constant mwseg			: integer := mw/64; 
	constant log2mwseg 		: integer := log2( mwseg ); 
	constant log2mwsegzeros	: std_logic_vector(log2mwseg-1 downto 0) := (others => '0');
	
	-- counter
	signal zjfin, zj1, lj, ej : std_logic;		 
	signal wc : std_logic_vector(log2mwseg-1 downto 0);

	-- fsm sigs
	type state_type is ( reset, wait_for_header1, load_block, wait_for_load1, wait_for_load2 );
	signal cstate_fsm1, nstate : state_type; 	  
		
	signal clr_f, set_f, f : std_logic;
	signal clr_bitpad, set_bitpad : std_logic;
	signal remblk, set_remblk, clr_remblk : std_logic;		  
	signal set_start_pad, clr_start_pad, start_pad : std_logic;				  
	signal set_full_block, clr_full_block, full_block : std_logic;
begin	 
	sr_rem_block : sr_reg 
	port map ( rst => rst, clk => clk, set => set_remblk, clr => clr_remblk, output => remblk);
	
	sr_final_block : sr_reg 
	port map ( rst => rst, clk => clk, set => set_f, clr => clr_f, output => f);
	
	sr_twbitpad : sr_reg 
	port map ( rst => rst, clk => clk, set => set_bitpad, clr => clr_bitpad, output => tw_bit_pad_en);
	
	
	-- fsm1 counter		
	word_counter_gen : countern generic map ( n => log2mwseg ) port map ( clk => clk, rst => '0', load => lj, en => ej, input => log2mwsegzeros, output => wc);
	zjfin <= '1' when wc = conv_std_logic_vector(mwseg-1,log2mwseg) else '0';				
	zj1 <= '1' when wc = 1 else '0';
	-- state process
	cstate_proc : process ( clk )
	begin
		if rising_edge( clk ) then 
			if rst = '1' then
				cstate_fsm1 <= reset;
			else
				cstate_fsm1 <= nstate;
			end if;
		end if;
	end process;
	
	nstate_proc : process ( cstate_fsm1, src_ready, load_next_block, zjfin, zc0, zcRem1, zcRemNon0, padded, final_segment, remblk, f )
	begin
		case cstate_fsm1 is
			when reset =>
				nstate <= wait_for_header1;
			when wait_for_header1 =>
				if ( src_ready = '1' ) then
					nstate <= wait_for_header1;				
				else 
					nstate <= wait_for_load1;
				end if;			
			when wait_for_load1 =>
				if (load_next_block = '0') then
					nstate <= wait_for_load1;
				else
					nstate <= load_block;
				end if;	 				
			when load_block =>		
				if (zjfin = '0') or (src_ready = '1' and (f = '0' or zc0 = '0' or comp_rem_e0 = '0' or full_block = '1')) then
					nstate <= load_block; 					
				elsif (((src_ready = '0' and comp_rem_e0 = '0') or comp_rem_e0 = '1') and zjfin = '1' and (zc0 = '0' or remblk = '1')) then
					nstate <= wait_for_load1;
				elsif (((src_ready = '0' and comp_rem_e0 = '0') or comp_rem_e0 = '1') and zjfin = '1' and zc0 = '1' and f = '1') then
					nstate <= wait_for_load2;
				else
					nstate <= wait_for_header1;
				end if;
		   when wait_for_load2 =>
		   		 if (load_next_block = '0') then
					nstate <= wait_for_load2;
				else
					nstate <= wait_for_header1;
				end if;
		end case;
	end process;
	
	-- fsm output	
	src_read <= '1' when 	((cstate_fsm1 = wait_for_header1 and src_ready = '0') or 
							(cstate_fsm1 = load_block and src_ready = '0' and (zc0 = '0' or comp_rem_e0 = '0' or full_block = '1'))) else '0';
	
	
	ej <= '1' when 	cstate_fsm1 = load_block and (
						(src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0' or f = '0' or full_block = '1')) or 
						(comp_rem_e0 = '1' and f = '1' and full_block = '0')
				) else '0';
	ein <= ej;
	
	
    block_ready_set <= '1' when 	cstate_fsm1 = load_block and zjfin = '1' and (
						(src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0' or f = '0' or full_block = '1')) or 
						(comp_rem_e0 = '1' and f = '1' and full_block = '0')
				) else '0';
				
	clr_f <= '1' when (cstate_fsm1 = reset) or (cstate_fsm1 = wait_for_load2 and load_next_block = '1')  else '0';	   		
	set_f <= '1' when (cstate_fsm1 = wait_for_header1 and final_segment = '1') else '0';
	lc <= '1' when (cstate_fsm1 = wait_for_header1) else '0';		
	lj <= '1' when ((cstate_fsm1 = reset)) else '0';  		
	ec <= '1' when 	cstate_fsm1 = load_block and zj1 = '1' and zc0 = '0' and (
						(src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0' or f = '0' or full_block = '1')) or 
						(comp_rem_e0 = '1' and f = '1' and full_block = '0')
				) else '0';

	set_remblk <= '1' when (cstate_fsm1 = load_block and ((src_ready = '0' and comp_rem_e0 = '0') or comp_rem_e0 = '1') and zj1 = '1' and zc0 = '0' and (zcRemNon0 = '1' or padded = '1')) else '0';
	clr_remblk <= '1' when (cstate_fsm1 = load_block and ((src_ready = '0' and comp_rem_e0 = '0') or comp_rem_e0 = '1') and zj1 = '1' and remblk = '1') else '0';
	
	eth <= '1' when 	cstate_fsm1 = load_block and zj1 = '1' and (zc0 = '0' or (zc0 = '1' and zcRem1 = '1' and padded = '1')) and (
						(src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0' or f = '0' or full_block = '1')) or 
						(comp_rem_e0 = '1' and f = '1' and full_block = '0')
		) else '0';	

	dth <= '1' when ((cstate_fsm1 = wait_for_load2 and load_next_block = '1') or (cstate_fsm1 = reset))  else '0';	   	-- equal to clr_f
	clr_rem <= '1' when (cstate_fsm1 = load_block and ((src_ready = '0' and comp_rem_e0 = '0') or comp_rem_e0 = '1') and zj1 = '1' and padded = '1' and zc0 = '1' and f = '1' and zcRem1 = '1') else '0';	

	msg_end_set <= '1' when (cstate_fsm1 = load_block and zjfin = '1' and zc0 = '1' and f = '1' and remblk = '0')  else '0';	
	
	set_bitpad <= '1' when (cstate_fsm1 = load_block and zj1 = '1' and zc0 = '1' and f = '1' and padded = '1') else '0';
	clr_bitpad <= '1' when (cstate_fsm1 = wait_for_load2 and load_next_block = '1') else '0';
		
		
	-- 
	en_lb <= '1' when (cstate_fsm1 = load_block and comp_lb_e0 = '0' and zc0 = '1' and full_block = '0' and src_ready = '0') else '0';
	clr_lb <= '1' when (cstate_fsm1 = load_block and comp_lb_e0 = '1' and zc0 = '1' and full_block = '0' and src_ready = '0') else '0';		
		
	sr_pos1 :  sr_reg 
        port map ( rst => rst, clk => clk, set => set_start_pad, clr => clr_start_pad, output => start_pad);
		
	spos <= '0' when (cstate_fsm1 = load_block and comp_lb_e0 = '1' and full_block = '0') else '1';
			
	set_start_pad <= clr_f;
	clr_start_pad <= '1' when cstate_fsm1 = load_block and f = '1' and full_block = '0' and (
						(comp_lb_e0 = '1' and comp_rem_e0 = '0' and src_ready = '0') or
						( comp_lb_e0 = '1' and comp_rem_e0 = '1')
					) else '0';
		
	sr_full_block : sr_reg 
		port map ( rst => rst, clk => clk, set => set_full_block, clr => clr_full_block, output => full_block);	
	set_full_block <= '1' when (cstate_fsm1 = wait_for_load1 and zc0 = '0') else '0';
	clr_full_block <= '1' when (cstate_fsm1 = load_block and zjfin = '1' and ej = '1') else '0';
	
	
end counter;