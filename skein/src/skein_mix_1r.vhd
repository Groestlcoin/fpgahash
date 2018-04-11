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

entity skein_mix_1r is		
	generic ( adder_type : integer := SCCA_BASED;
			  col : integer := 0 );
	port ( 							 
		rsel : in std_logic_vector(2 downto 0);
		a : in std_logic_vector(iw-1 downto 0);
		b : in std_logic_vector(iw-1 downto 0);
		c, d : out std_logic_vector(iw-1 downto 0) 
	);
end skein_mix_1r;

architecture struct of skein_mix_1r is
	signal c_out : std_logic_vector(iw-1 downto 0);	  
	signal b_rotate :  std_logic_vector(iw-1 downto 0);
begin
	add_call1 : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => a, b => b, s => c_out);	
	with rsel select
	b_rotate <= rolx(b,rot_512(col,0)) when "000",
				rolx(b,rot_512(col,1)) when "001",
				rolx(b,rot_512(col,2)) when "010",
				rolx(b,rot_512(col,3)) when "011",
				rolx(b,rot_512(col,4)) when "100",
				rolx(b,rot_512(col,5)) when "101",
				rolx(b,rot_512(col,6)) when "110",
				rolx(b,rot_512(col,7)) when others;
	c <= c_out;
	d <= b_rotate xor c_out;
end struct;