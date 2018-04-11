-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use ieee.std_logic_1164.all;			
use ieee.std_logic_unsigned.all; 
use ieee.std_logic_arith.all;
use work.sha3_jh_package.all;
use work.sha3_pkg.all;

entity jh_fsm1 is	   
	port (
	clk : in std_logic;
	rst : in std_logic;		
	
	-- datapath sigs
	zc0, final_segment	: in std_logic;
	lc, ec : out std_logic;
	ein : out std_logic;
		        
    comp_rem_e0, comp_lb_e0 : in std_logic;
    en_lb, clr_lb : out std_logic; 
	rst_size, en_size : out std_logic;
    spos, sel_pad : out std_logic_vector(1 downto 0);
       
	-- Control communication
	load_next_block	: in std_logic;		 
	block_ready_set : out std_logic;
	msg_end_set : out std_logic;
	
	-- FIFO communication
	src_ready : in std_logic;
	src_read    : out std_logic	
	);
end jh_fsm1;

architecture nocounter of jh_fsm1 is	
	-- counter
	signal zjfin, lj, ej : std_logic;		 
	signal wc : std_logic_vector(log2mwseg-1 downto 0);

	-- fsm sigs
	type state_type is ( reset, wait_for_header1, load_block, wait_for_load1, wait_for_load2, wait_for_load3,
        load_last_block, load_padded_block);
	signal cstate_fsm1, nstate : state_type; 			 
	
	-- 
	signal f, lf, ef : std_logic;
    signal set_start_pad, clr_start_pad, start_pad : std_logic;
	signal lc_s : std_logic;
begin	 						 
	-- final seg register
	sr_final_segment :  sr_reg 
	port map ( rst => rst, clk => clk, set => ef, clr => lf, output => f);
	
	-- fsm1 counter		
	word_counter_gen : countern generic map ( n => log2mwseg ) port map ( clk => clk, rst => '0', load => lj, en => ej, input => log2mwsegzeros, output => wc);
	zjfin <= '1' when wc = conv_std_logic_vector(mwseg-1,log2mwseg) else '0';	
	
	
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
	
	nstate_proc : process ( cstate_fsm1, src_ready, load_next_block, zjfin, zc0, final_segment, f, comp_rem_e0  )
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
				elsif ( zc0 = '1' and f = '1' and comp_rem_e0 = '1') then
                    nstate <= load_padded_block;
                elsif ( zc0 = '1' and f = '1' and comp_rem_e0 = '0') then
                    nstate <= load_last_block;
                else
					nstate <= load_block;
				end if;	 				
			when load_block =>		
				if ((src_ready = '1') or (src_ready = '0' and zjfin = '0')) then
					nstate <= load_block; 					
				elsif ((src_ready = '0') and (zjfin = '1') and (zc0 = '0')) then
					nstate <= wait_for_load1;				
				elsif ((src_ready = '0') and (zjfin = '1') and (zc0 = '1') and (f = '1')) then
					nstate <= wait_for_load2;
				else
					nstate <= wait_for_header1;
				end if;			
            when wait_for_load2 =>
                if (load_next_block = '0') then
                    nstate <= wait_for_load2;
                elsif comp_rem_e0 = '1' then
                    -- padded block
                    nstate <= load_padded_block;
                else
                    -- last block
                    nstate <= load_last_block;
                end if;
            when load_padded_block =>
                if (zjfin = '1') then
                    nstate <= wait_for_load3;
                else
                    nstate <= load_padded_block;
                end if;
            when load_last_block =>
                if (zjfin = '1') then
                    nstate <= wait_for_load2;
                else
                    nstate <= load_last_block;
                end if;
            when wait_for_load3 =>
                if (load_next_block = '0') then
                    nstate <= wait_for_load3;
                else
                    nstate <= wait_for_header1;
                end if;
		end case;
	end process;
	
	-- fsm output
	
	src_read <= '1' when 	((cstate_fsm1 = wait_for_header1 and src_ready = '0') or 
							(cstate_fsm1 = load_last_block and src_ready = '0' and comp_rem_e0 = '0') or
							(cstate_fsm1 = load_block and src_ready = '0')) else '0';
		
	ein <= '1' when (cstate_fsm1 = load_block and src_ready = '0') or 
					(cstate_fsm1 = load_last_block and  ((src_ready = '0' and comp_rem_e0 = '0') or (comp_rem_e0 = '1')))  or
					(cstate_fsm1 = load_padded_block) else '0';
						 
	ej <= '1' when 	(cstate_fsm1 = load_block and src_ready = '0') or 
					(cstate_fsm1 = load_last_block and ((src_ready = '0' and comp_rem_e0 = '0') or (comp_rem_e0 = '1')))  or
					(cstate_fsm1 = load_padded_block) else '0';
						 
    block_ready_set <= '1' when ((cstate_fsm1 = load_block and src_ready = '0' and zjfin = '1') or
								(cstate_fsm1 = load_last_block and zjfin = '1' and ((src_ready = '0' and comp_rem_e0 = '0') or (comp_rem_e0 = '1'))) or
								(cstate_fsm1 = load_padded_block and zjfin = '1')) else '0';
						
	msg_end_set <= '1' when (cstate_fsm1 = wait_for_load3 and load_next_block = '1' )  else '0';
	
	lf <= '1' when (cstate_fsm1 = reset) or 
                    (cstate_fsm1 = wait_for_load3 and load_next_block = '1')  else '0';	   
		
	ef <= '1' when (cstate_fsm1 = wait_for_header1 and final_segment = '1') else '0';
		
	lc_s <= '1' when (cstate_fsm1 = wait_for_header1 and src_ready = '0') else '0';
		
	lj <= '1' when ((cstate_fsm1 = reset)) else '0';  
		
	ec <= '1' when 	(cstate_fsm1 = wait_for_load1 and load_next_block = '1' and zc0 = '0') else '0';		
		
	-- msize control
	rst_size <= lf;
	en_size <= lc_s;
	lc <= lc_s;
	
	-- spos controls	
	sr_pos1 :  sr_reg 
        port map ( rst => rst, clk => clk, set => set_start_pad, clr => clr_start_pad, output => start_pad);
	spos <= "00" when (cstate_fsm1 = load_last_block or cstate_fsm1 = load_padded_block) and (comp_lb_e0 = '1' and start_pad = '0') else	-- select '0'
			"01" when (cstate_fsm1 = load_last_block or cstate_fsm1 = load_padded_block) and (comp_lb_e0 = '1' and start_pad = '1') else 	-- select start pad
			"11";																												 
	set_start_pad <= lf;
	clr_start_pad <= '1' when (cstate_fsm1 = load_last_block or cstate_fsm1 = load_padded_block) and 
								((comp_lb_e0 = '1' and comp_rem_e0 = '0' and src_ready = '0' and start_pad = '1') or ( comp_lb_e0 = '1' and comp_rem_e0 = '1')) else '0';
							   
	-- select pad control
	sel_pad(0) <= '1' when zjfin = '1' else '0';
	sel_pad(1) <= '0' when (cstate_fsm1 = load_padded_block and (wc=6 or wc=7)) else '1';
		
	-- last block counter
	en_lb <= '1' when (cstate_fsm1 = load_last_block and comp_lb_e0 = '0' and src_ready = '0') else '0';
	clr_lb <= '1' when (cstate_fsm1 = load_last_block and comp_lb_e0 = '1' and src_ready = '0') else '0';
	
end nocounter;