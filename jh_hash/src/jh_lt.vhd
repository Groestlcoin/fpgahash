-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;  
use work.sha3_pkg.all;

entity jh_lt is
	port
	(
		a: in std_logic_vector(3 downto 0);
		b: in std_logic_vector(3 downto 0);
		c: out std_logic_vector(3 downto 0);
		d: out std_logic_vector(3 downto 0)
	);
end jh_lt;

architecture struct of jh_lt is
	signal temp: std_logic_vector(3 downto 0);
begin	  
	temp <= (rolx(a,1) xor b) xor ("00" & a(3) & '0');
	c <= (rolx(temp,1) xor a) xor ("00" & temp(3) & '0');
	d <= temp;
end struct;

architecture struct2 of jh_lt is
begin  
	d <= (a(2) xor b(3)) & 
		 (a(1) xor b(2)) & 
		 (a(0) xor a(3) xor b(1)) & 
		 (a(3) xor b(0));
	   
	c <= ((a(1) xor a(3)) xor b(2)) &
		 ((a(0) xor a(2)) xor (a(3) xor b(1))) & 
		 (((a(1) xor a(2)) xor (a(3) xor b(0))) xor b(3)) &
		 ((a(0) xor a(2)) xor b(3));
end struct2;

	
	