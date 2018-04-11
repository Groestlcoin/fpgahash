-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use ieee.std_logic_1164.all;			
use ieee.std_logic_unsigned.all; 
use ieee.std_logic_arith.all;
use work.sha3_blake_package.all;
use work.sha3_pkg.all;

entity blake_fsm1 is 
	generic ( HS : integer := 256; BS : integer := 512 );
	port (
	clk : in std_logic;
	rst : in std_logic;		
	
	-- datapath sigs
	zc0, zc1, final_segment	: in std_logic;
	ein, lc, ec : out std_logic;
	eth, dt, etl, sel_t  : out std_logic;		 
	lm : out std_logic;	 
	
	-- pad
	comp_rem_mt440, comp_rem_e0, comp_lb_e0 : in std_logic;
    last_word, en_lb, clr_lb : out std_logic; 
	sel_pad : out std_logic_vector(HS/256-1 downto 0);
    spos : out std_logic_vector(1 downto 0);
		
	-- Control communication	  
	
	computing : in std_logic;
	load_next_block	: in std_logic;
	block_ready_set : out std_logic;
	msg_end_set : out std_logic;  
	
	-- FIFO communication
	src_ready : in std_logic;
	src_read    : out std_logic	
	);
end blake_fsm1;

architecture counter of blake_fsm1 is
	
	constant mw				: integer := BS;		-- message width	
	constant mwseg			: integer := mw/64; 
	constant log2mwseg 		: integer := log2( mwseg ); 
	constant log2mwsegzeros	: std_logic_vector(log2mwseg-1 downto 0) := (others => '0');
	
	-- counter
	signal zjfin, lj, ej : std_logic;		 
	signal wc : std_logic_vector(log2mwseg-1 downto 0);

	-- fsm sigs
	type state_type is ( reset, wait_for_header1, load_block, wait_for_load1, wait_for_load2 );
	signal cstate_fsm1, nstate : state_type; 	  
		
	signal clr_f, set_f, f : std_logic;
	signal zj1 : std_logic;			 
	signal extra_block, set_extra_block, clr_extra_block : std_logic;
	
	signal set_start_pad, clr_start_pad, start_pad : std_logic;
	signal set_empty_block, clr_empty_block, empty_block : std_logic;
	signal spos_sig : std_logic_vector(1 downto 0);
	signal set_full_block, clr_full_block, full_block : std_logic;
begin		
	sr_final_block : sr_reg 
	port map ( rst => rst, clk => clk, set => set_f, clr => clr_f, output => f);	   
	
	

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
	
	nstate_proc : process ( cstate_fsm1, src_ready, load_next_block, zjfin, zc0, final_segment, computing, f, extra_block, comp_rem_e0, zc1 )
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
				if ((src_ready = '1' and (f = '0' or zc0 = '0' or comp_rem_e0 = '0' or full_block = '1')) or zjfin = '0' or computing = '1' ) then
					nstate <= load_block;	
				elsif (zjfin = '1' and zc0 = '1' and comp_rem_e0 = '1' and f = '1' and extra_block = '0') then
					nstate <= wait_for_load2;																
				elsif (src_ready = '0' and zjfin = '1' and f = '0' and zc0 = '1') then
					nstate <= wait_for_header1;										
				else
					nstate <= wait_for_load1;
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
	sr_full_block : sr_reg 
		port map ( rst => rst, clk => clk, set => set_full_block, clr => clr_full_block, output => full_block);	
	set_full_block <= '1' when (cstate_fsm1 = wait_for_load1 and zc0 = '0') else '0';
	clr_full_block <= '1' when (cstate_fsm1 = load_block and zjfin = '1' and ej = '1') else '0';
	
	sr_extra_block : sr_reg 
		port map ( rst => rst, clk => clk, set => set_extra_block, clr => clr_extra_block, output => extra_block);	
	set_extra_block <= '1' when (cstate_fsm1 = wait_for_load1 and comp_rem_mt440 = '1' and zc0 = '1' and f = '1') or	 
								(cstate_fsm1 = wait_for_load1 and comp_rem_e0 = '1' and zc1 = '1' and f = '1') or
							    (cstate_fsm1 = load_block and wc = 0 and comp_rem_mt440 = '1' and zc0 = '1' and f = '1') else '0';
	clr_extra_block <= '1' when (cstate_fsm1 = reset) or (cstate_fsm1 = wait_for_load1 and load_next_block = '1' and extra_block = '1' and full_block = '0') else '0';
		
	sr_empty_block : sr_reg 
		port map ( rst => rst, clk => clk, set => set_empty_block, clr => clr_empty_block, output => empty_block);	
	set_empty_block <= '1' when (cstate_fsm1 = wait_for_load1 and extra_block = '1' and load_next_block = '1') else '0';
	clr_empty_block <= '1' when (cstate_fsm1 = reset) or (cstate_fsm1 = wait_for_load2 and load_next_block = '1') else '0';
	sel_t <= '1' when (cstate_fsm1 = wait_for_load2 and empty_block = '1') else '0';
			 		
	lm <= '1' when (zjfin = '1' and computing = '0') else '0';
	dt <= '1' when ((cstate_fsm1 = reset) or 
					(cstate_fsm1 = wait_for_load2 and load_next_block = '1')) else '0';	
		
	src_read <= '1' when 	(cstate_fsm1 = wait_for_header1 and src_ready = '0') or 						
							(cstate_fsm1 = load_block and ej = '1' and spos_sig = "11" and src_ready = '0') or 
							((cstate_fsm1 = load_block and ej = '1' and spos_sig = "01" and full_block = '0') and comp_rem_e0 = '0' and src_ready = '0') else '0';						
						 
	ej <= '1' when 	cstate_fsm1 = load_block and (zjfin = '0' or (zjfin = '1' and computing = '0')) and (
						(src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0' or f = '0' or full_block = '1')) or 
						(comp_rem_e0 = '1' and f = '1' and full_block = '0'))
				 else '0';
	ein <= ej;
						 
    block_ready_set <= '1' when cstate_fsm1 = load_block and zjfin = '1' and computing = '0' and (
								(src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0' or f = '0' or full_block = '1')) or 
								(comp_rem_e0 = '1' and f = '1' and full_block = '0')) else '0';
						
	msg_end_set <= '1' when (cstate_fsm1 = wait_for_load2 and load_next_block = '1' and f = '1' )  else '0';
	
	clr_f <= '1' when (cstate_fsm1 = reset) or (cstate_fsm1 = wait_for_load2 and load_next_block = '1')  else '0';	   		
	set_f <= '1' when (cstate_fsm1 = wait_for_header1 and final_segment = '1') else '0';

	lc <= '1' when (cstate_fsm1 = wait_for_header1) else '0';
		
	lj <= '1' when ((cstate_fsm1 = reset)) else '0';  
	
	ec <= '1' when 	(cstate_fsm1 = load_block and ((src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0')) or (comp_rem_e0 = '1' and zc0 = '1')) and zj1 = '1' and zc0 = '0' ) else '0';		
	eth <= '1' when (cstate_fsm1 = load_block and ((src_ready = '0' and (comp_rem_e0 = '0' or zc0 = '0')) or (comp_rem_e0 = '1' and zc0 = '1')) and zj1 = '1' and zc0 = '0' ) else '0';
	etl <= '1' when (cstate_fsm1 = load_block and zc0 = '1' and f = '1' and comp_rem_e0 = '0' and wc = 0) else '0';	
		
	-- spos controls	
	sr_pos1 :  sr_reg 
        port map ( rst => rst, clk => clk, set => set_start_pad, clr => clr_start_pad, output => start_pad);
	spos_sig <= "00" when (cstate_fsm1 = load_block and full_block = '0' and f = '1' and comp_lb_e0 = '1' and start_pad = '0') else	-- select '0'
			"01" when (cstate_fsm1 = load_block and full_block = '0' and f = '1' and comp_lb_e0 = '1' and start_pad = '1') else 	-- select start pad
			"11"; 
	spos <= spos_sig;
	set_start_pad <= '1' when (cstate_fsm1 = wait_for_header1 and final_segment = '1' ) else '0';
	clr_start_pad <= '1' when (cstate_fsm1 = load_block and full_block = '0' and f = '1' and comp_lb_e0 = '1' and start_pad = '1' and ej = '1') else '0';
							   
	-- select pad control
	h256_gen : if HS = 256 generate
		sel_pad(0) <= '1' when (cstate_fsm1 = load_block and zjfin = '1' and extra_block = '0' and full_block = '0' and f = '1' ) else '0';
		-- last word indicator
		last_word <= '1' when (cstate_fsm1 = load_block and wc = 6 and full_block = '0' and f = '1' and extra_block = '0') else '0';
	end generate;
	h512_gen : if HS = 512 generate
		sel_pad(0) <= '1' when (cstate_fsm1 = load_block and zjfin = '1' and extra_block = '0' and full_block = '0' and f = '1' ) else '0';		
		sel_pad(1) <= '1' when (cstate_fsm1 = load_block and (wc = conv_std_logic_vector(mwseg-2,log2mwseg) or zjfin = '1') and extra_block = '0' and full_block = '0' and f = '1' ) else '0';
		-- last word indicator
		last_word <= '1' when (cstate_fsm1 = load_block and wc = 13 and full_block = '0' and f = '1' and extra_block = '0') else '0';
	end generate;
			
	-- last block counter
	en_lb <= '1' when (cstate_fsm1 = load_block and full_block = '0' and f = '1' and comp_lb_e0 = '0' and src_ready = '0') else '0';
	clr_lb <= '1' when (cstate_fsm1 = load_block and full_block = '0' and f = '1' and comp_lb_e0 = '1' and src_ready = '0' and ej = '1') else '0';			
end counter;