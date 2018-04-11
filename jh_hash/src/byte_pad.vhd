-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;

entity byte_pad is
    generic( w:integer := 32);
    port ( din 				: in  std_logic_vector(w-1 downto 0);
           dout 			: out std_logic_vector(w-1 downto 0);
           sel_pad_location	: in  std_logic_vector(w/8-1 downto 0);
		   sel_din 			: in  std_logic_vector(w/8-1 downto 0)
	);
end byte_pad;

architecture struct of byte_pad is				   	
	type byte_pad_type is array (w/8-1 downto 0) of std_logic_vector(7 downto 0);
	signal byte_pad_wire	: byte_pad_type;
begin	 																	 
	byte_pad_gen : for i in w/8-1 downto 0 generate
		byte_pad_wire(i)<= X"80" when sel_pad_location(i) = '1' else X"00";
		dout(8*(i+1)-1 downto 8*i) <= din(8*(i+1)-1 downto 8*i) when sel_din(i) = '1' else byte_pad_wire(i);		
	end generate;
end struct;
    