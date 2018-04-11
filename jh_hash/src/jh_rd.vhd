-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;	   
use ieee.std_logic_arith.all;
use work.sha3_pkg.all;
use work.sha3_jh_package.all;

entity jh_rd is
	generic ( bw : integer := 1024;							-- input size
			  cw : integer := 256);						-- constant size		
	port (
		input	: in std_logic_vector(bw-1 downto 0);		--input
		cr		: in std_logic_vector(cw-1 downto 0);		--key	
		output 	: out std_logic_vector(bw-1 downto 0)
	);
end jh_rd;

architecture struct of jh_rd is
	type array_type is array (0 to cw-1) of std_logic_vector(3 downto 0);
	signal aa, vv, ww, permuted : array_type;		   
	signal permuted_blk : std_logic_vector(bw-1 downto 0);
begin
	
	-- separate inputs into array of 4 bits word for easy processing
	array4_gen : for i in bw/4-1 downto 0 generate
		aa(bw/4-1 - i) <= input(i*4+3 downto i*4);  			
		permuted_blk(i*4+3 downto i*4) <= permuted(bw/4-1 - i);
	end generate;
	
	-- apply sbox
	sbox_gen : for i in 0 to cw-1 generate
		vv(i) <= sbox_rom(conv_integer(cr(cw-1-i)),conv_integer(unsigned(aa(i))));
	end generate;
	
	-- apply linear transformation
	lt_gen : for i in 0 to cw/2-1 generate
		lt_box : entity work.jh_lt(struct) port map ( a => vv(2*i), b => vv(2*i+1), c => ww(2*i), d => ww(2*i+1) );
	end generate;	

	perm_gen : for i in 0 to cw/4-1 generate
		permuted(i*2)   		<= ww(4*i);
		permuted(i*2+1) 		<= ww(4*i+3);
		permuted(cw/2 + i*2) 	<= ww(4*i+2);
		permuted(cw/2 + i*2+1) 	<= ww(4*i+1);			
	end generate;			
	output <= permuted_blk;
end struct;											   



architecture no_perm of jh_rd is
	type array_type is array (0 to cw-1) of std_logic_vector(3 downto 0);
	signal aa, vv, ww : array_type;		   
	signal ww_blk : std_logic_vector(bw-1 downto 0);
	
--	--debug		
--	signal pi_blk, pp_blk : std_logic_vector(b-1 downto 0);
--	signal input_m, vv_blk_m, ww_blk_m, pp_m, pi_m, phi_m: std_logic_matrix;
begin
	
	-- separate inputs into array of 4 bits word for easy processing
	array4_gen : for i in bw/4-1 downto 0 generate
		aa(bw/4-1 - i) <= input(i*4+3 downto i*4); 
		ww_blk(i*4+3 downto i*4) <= ww(bw/4-1 - i);
	end generate;
	
	-- apply sbox
	sbox_gen : for i in 0 to cw-1 generate
		--vv(i) <= sbox_rom(0,conv_integer(unsigned(aa(i)))) when cr(i) = '0' else sbox_rom(1,conv_integer(unsigned(aa(i))));
		vv(i) <= sbox_rom(conv_integer(cr(cw-1-i)),conv_integer(unsigned(aa(i))));
	end generate;
	
	-- apply linear transformation
	lt_gen : for i in 0 to cw/2-1 generate
		lt_box : entity work.jh_lt(struct) port map ( a => vv(2*i), b => vv(2*i+1), c => ww(2*i), d => ww(2*i+1) );
	end generate;
	
	output <= ww_blk;			
end no_perm;


