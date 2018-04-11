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
use work.sha3_skein_package.all;

entity skein_keygen is	
	generic ( 	version : integer := SHA3_ROUND3;
				adder_type : integer := SCCA_BASED;
				b : integer := 512; 
				nw : integer := 8; 
				key_size : integer := 1 );
	port (					
		clk		: in std_logic;
		load	: in std_logic;
		en		: in std_logic;
		keyin	: in std_logic_vector(b-1 downto 0);
		tweak 	: in std_logic_vector(127 downto 0);
		keyout	: out round_array(key_size-1 downto 0, nw-1 downto 0)
	);
end skein_keygen;
		
architecture struct of skein_keygen is
	-- tweak															   
	type tweak_type is array (2 downto 0) of std_logic_vector(63 downto 0);
	type tweak_array is array (key_size downto 0, 2 downto 0) of std_logic_vector(63 downto 0);
	signal tw_iv, tw_reg : tweak_type;
	signal tw : tweak_array;
				
	type key_type1 is array(nw downto 1) of std_logic_vector(63 downto 0);
	signal key_reg : key_type1;	 
	
	signal key_out_in : round_array(key_size-1 downto 0, nw-1 downto 0);
	signal key 	: round_array(key_size-1 downto 0, nw downto 0) ;
	signal parkey   : round_array(key_size-1 downto 0, nw-1 downto 0) ;

	-- sub key counter	
	signal s_out : std_logic_vector(6 downto 0);
	type subkey_array is array(key_size downto 0) of std_logic_vector(6 downto 0);
	signal s : subkey_array;
	constant fiftysevenzeros : std_logic_vector(56 downto 0) := (others => '0');
	
	constant key_const : std_logic_vector(63 downto 0) := get_key_const( version );
begin					  
	----------------------
	-- s gen 
	s(0) <= "0000000" when load = '1' else s_out;
	s_reg_gen : regn generic map ( N => 7, init => "0000000" ) port map (clk => clk, rst => '0', en => en, input => s(key_size), output => s_out );
	s_array_gen : for i in 1 to key_size generate
		add_call : adder generic map ( adder_type => adder_type, n => 7 ) port map ( a => s(i-1), b => "0000001", s => s(i));
	end generate;
	
	----------------------
	-- tweak
		--tweak init	   
	tw_iv(2) <= tweak(127 downto 64) xor tweak(63 downto 0);
	tw_iv(1) <= tweak(127 downto 64);
	tw_iv(0) <= tweak(63 downto 0);
	
		--
	tw(0,0) <= tw_iv(0) when load = '1' else tw_reg(0);
	tw(0,1) <= tw_iv(1) when load = '1' else tw_reg(1);
	tw(0,2) <= tw_iv(2) when load = '1' else tw_reg(2);
	
	tweak_loop_gen : for i in 1 to key_size generate
		tw(i,0) <= tw(i-1,1);
		tw(i,1) <= tw(i-1,2);
		tw(i,2) <= tw(i-1,0);
	end generate;
	
	tw_regs_gen : for i in 2 downto 0 generate
		tw_reg_gen : regn generic map ( N => iw, init => iwzeros ) port map ( clk => clk, rst => '0', en => en, input => tw(key_size,i), output => tw_reg(i) );
	end generate;	
	
	----------------------
	-- key
	key_gen : for i in nw-1 downto 0 generate
		key(0,i) <= keyin(iw*i+iw-1 downto i*iw) when load = '1' else key_reg(i+1);
	end generate;
	key(0,nw) <= parkey(0,nw-1) xor key_const;
	
	
	parkey_gen : for i in 0 to key_size-1 generate
		parkey(i,0) <= key(i,0);
		parkey_gen2 : for j in 1 to nw-1 generate
			parkey(i,j) <= key(i,j) xor parkey(i,j-1);
		end generate;
	end generate;
	
	-- for key_size > 1 
	key_size_x : if key_size > 1 generate
		key_gen1 : for i in 1 to key_size-1 generate	
			key_gen2 : for j in nw-1 downto 0 generate
				key(i,j) <= key(i-1,j+1);
			end generate;
			key(i,nw) <= parkey(i,nw-1) xor key_const;
		end generate;		
	end generate;			
	
	keyout_reg : for i in 0 to key_size-1 generate
		-- gen key out				   
			-- 7-bit adder with propagation (use the basic + )
		key_out_in(i,nw-1) <= key(i,nw-1) + s(i);
		add_call2 : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => key(i,nw-2), b => tw(i,1), s => key_out_in(i,nw-2));
		add_call3 : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => key(i,nw-3), b => tw(i,0), s => key_out_in(i,nw-3));
		key_out_in_gen : for j in nw-4 downto 0 generate
			key_out_in(i,j) <= key(i,j);
		end generate;
		-- gen reg
		keyout_reg2 : for j in nw-1 downto 0 generate
			key_out_gen : regn generic map ( N => iw, init => iwzeros ) port map ( clk => clk, rst => '0', en => en, input => key_out_in(i,j), output => keyout(i,j) );
		end generate;						   
	end generate;
	
	reggen_keyreg : for j in nw downto 1 generate
		key_reg_gen : regn generic map ( N => iw, init => iwzeros ) port map ( clk => clk, rst => '0', en => en, input => key(key_size-1,j), output => key_reg(j) );
	end generate;
			

end struct;