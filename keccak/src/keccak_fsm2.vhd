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
use work.keccak_pkg.all;

-- keccak fsm2 is responsible for keccak computation processing 

entity keccak_fsm2 is  
generic (hs:integer:=HASH_SIZE_256);	
	port (
		clk 					: in std_logic;
		rst 					: in std_logic;

		wr_state				: out std_logic;
		sel_xor 				: out std_logic;
		
		sel_final				: out std_logic;
		ld_rdctr				: out std_logic;
		en_rdctr 				: out std_logic; 
	
		block_ready_clr 		: out std_logic;		
		msg_end_clr 			: out std_logic;
		block_ready				: in std_logic;
		msg_end 				: in std_logic;	 
		lo						: out std_logic;
		output_write_set 		: out std_logic;
		output_busy_set  		: out std_logic;
		output_busy		 		: in  std_logic);							   
end keccak_fsm2;


architecture beh of keccak_fsm2 is					 
	constant roundnr 		: integer := 24;  
	constant log2roundnr	: integer := log2( roundnr );
	constant log2roundnrzeros : std_logic_vector(log2roundnr-1 downto 0) := (others => '0') ;
	
	type state_type is ( reset, idle, process_block, process_last_block, finalization, output_data );
	signal cstate, nstate : state_type;
   
	signal pc : std_logic_vector(log2roundnr-1 downto 0);
	signal ziroundnr, li, ei : std_logic;
	signal output_data_s : std_logic;						 	
   	signal sel_xor_set, sel_xor_clr, sel_xor_wire : std_logic;	-- select first message
	
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
					nstate <= process_block;				 
				elsif (block_ready = '1' and msg_end = '1') then
					nstate <= process_last_block;
				else
					nstate <= idle;
				end if;	    
			when process_block =>
				if ( ziroundnr = '0' ) or (ziroundnr = '1' and msg_end = '0' and block_ready = '1') then				
					nstate <= process_block;					
				elsif (ziroundnr = '1' and msg_end = '1') then
					nstate <= process_last_block;
				else
					nstate <= idle;
				end if;			
			when process_last_block => 
				if ( ziroundnr = '0' ) then				
					nstate <= process_last_block;					
				elsif (ziroundnr = '1') then
					nstate <= finalization;
				else
					nstate <= idle;
				end if;			
			when finalization => 
				if ( output_busy = '1' ) then
					nstate <= output_data;										  
				elsif (block_ready = '1' and msg_end = '1') then
					nstate <= process_last_block;					
				elsif (block_ready = '1') then
					nstate <= process_block;						
				else
					nstate <= idle;
				end if;
				
			when output_data =>
				if ( output_busy = '1' ) then
					nstate <= output_data;
				elsif (block_ready = '1' and msg_end = '1') then
					nstate <= process_last_block;					
				elsif (block_ready = '1') then
					nstate <= process_block;			  
				else 
					nstate <= idle;
				end if;				
		end case;
	end process;
	
	
	---- output logic	
	output_data_s <= '1' when ((cstate = finalization and output_busy = '0') or 
								  (cstate = output_data and output_busy = '0')) else '0';
	output_write_set	<= output_data_s;
	output_busy_set 	<= output_data_s;
	lo					<= output_data_s;
	
	
	block_ready_clr		<= '1' when ((cstate = process_block or cstate = process_last_block) and pc = 4) else '0';

	
	ei <= '1' when (cstate = process_block or cstate = process_last_block) else '0';
											
	li <=  '1' when  (cstate = reset) or ( cstate = idle )or (ziroundnr = '1') else '0';
	
	
	sf_gen : sr_reg 
		generic map ( init => '1' )
		port map ( rst => rst, clk => clk, set => sel_xor_set, clr => sel_xor_clr, output => sel_xor_wire);	
	sel_xor_set <= '1' when (cstate = reset) or (cstate = process_last_block and ziroundnr = '1') else '0';
	sel_xor_clr <= '1' when sel_xor_wire = '1' and 
						((cstate = idle and block_ready = '1') or 
						(cstate = finalization and output_busy = '0' and block_ready = '1') or
						( cstate = output_data and block_ready = '1' and output_busy = '0')) else '0';
	sel_xor <= sel_xor_wire;
	
		
	sel_final <= '1' when  (cstate = idle and block_ready = '1') or 
							(cstate = process_block and ziroundnr = '1') or	  
							(cstate = finalization and output_busy = '0' and block_ready = '1') or
						(cstate = output_data and output_busy = '0' and block_ready = '1') else '0';
			  
	ld_rdctr <= '1' when (cstate = idle and block_ready = '1') or ((cstate = process_block) and ziroundnr = '1' and block_ready = '1') or 
						(cstate = process_last_block and ziroundnr = '1') else '0';
	en_rdctr <= '1' when ((cstate = process_block or cstate = process_last_block) and ziroundnr = '0') else '0';		
	
	wr_state <= '1' when (cstate = idle and block_ready = '1') or 									
						(cstate = process_block and ziroundnr = '0') or 
						((cstate = process_block) and ziroundnr = '1' and ((msg_end = '0' and block_ready = '1') or (msg_end = '1'))) or
						(cstate = process_last_block) or   
						(cstate = finalization and output_busy = '0' and block_ready = '1') or 
						(cstate = output_data and output_busy = '0' and block_ready = '1') else '0';
							
	
	msg_end_clr <= '1' when (cstate = idle and block_ready = '1' and msg_end = '1') or 		
							(cstate = process_block and block_ready = '1' and msg_end = '1' and ziroundnr = '1') or	 
							(cstate = finalization and output_busy = '0' and block_ready = '1' and msg_end = '1') or 
							(cstate = output_data and output_busy = '0' and block_ready = '1' and msg_end = '1') else '0';
							
end beh;