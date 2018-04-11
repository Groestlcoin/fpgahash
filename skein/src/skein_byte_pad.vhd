-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
			  
entity skein_byte_pad is
    generic( w:integer := 32);
    port ( din 				: in  std_logic_vector(w-1 downto 0);
           dout 			: out std_logic_vector(w-1 downto 0);          
		   sel_din 			: in  std_logic_vector(w/8-1 downto 0)
	);
end skein_byte_pad;

architecture struct of skein_byte_pad is				   	
begin	 																	 
	byte_pad_gen : for i in w/8-1 downto 0 generate
		dout(8*(i+1)-1 downto 8*i) <= din(8*(i+1)-1 downto 8*i) when sel_din(i) = '1' else x"00";		
	end generate;
end struct;

