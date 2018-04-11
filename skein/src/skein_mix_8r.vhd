-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; 
use work.sha3_pkg.all;
use work.sha3_skein_package.all;

entity skein_mix_8r is		
	generic ( adder_type : integer := SCCA_BASED; rotate : integer := 1 );
	port ( 
		a : in std_logic_vector(iw-1 downto 0);
		b : in std_logic_vector(iw-1 downto 0);
		c, d : out std_logic_vector(iw-1 downto 0) 
	);
end skein_mix_8r;

architecture struct of skein_mix_8r is
	signal temp : std_logic_vector(iw-1 downto 0);
begin
	add_call1 : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => a, b => b, s => temp);
	
	c <= temp;
	d <= rolx(b,rotate) xor temp;
end struct;