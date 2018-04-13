-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;   
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all; 
use work.sha3_pkg.all;
use work.groestl_pkg.all;												  

entity groestl_pq_parallel is
generic (n:integer := GROESTL_DATA_SIZE_SMALL; rom_style : integer := DISTRIBUTED; p_mode : integer := 1);
port( 
	round			: in std_logic_vector(7 downto 0);
	input 			: in std_logic_vector(n-1 downto 0);
   	output 			: out std_logic_vector(n-1 downto 0));
end groestl_pq_parallel;  		

architecture round3_combinational of groestl_pq_parallel is

signal	subbyte_out, shiftout		: std_logic_vector(n-1 downto 0);
signal	addcons			: std_logic_vector(n-1 downto 0);

begin
				
	pmode0Gen: 
		if p_mode = 0 generate
			addconsGen: 
				for i in 0 to n/64-1 generate
					addcons(i*64+63 downto i*64+ 8) <= not input(i*64+63 downto i*64+ 8);
					addcons(i*64+ 7 downto i*64+ 0) <= (conv_std_logic_vector((16-n/64)+i,4) & x"F" ) xor input(i*64+ 7 downto i*64+ 0) xor round;
				end generate;
			
			srq:
				entity work.groestl_shiftrow(groestl_shiftrowq) 
				generic map (n=>n)
				port map (input=>addcons, output=>shiftout);
		end generate;  
		
	pmode1Gen: 
		if p_mode = 1 generate
			addconsGen: 
				for i in 0 to n/64-1 generate
					addcons(i*64+63 downto i*64+56) <= input(i*64+63 downto i*64+56) xor round xor (conv_std_logic_vector(n/64-1-i,4) & x"0" );
					addcons(i*64+55 downto i*64+ 0) <= input(i*64+55 downto i*64+ 0);
				end generate;
			
			srp:			
				entity work.groestl_shiftrow(groestl_shiftrowp) 
				generic map (n=>n)
				port map (input=>addcons, output=>shiftout);
		end generate;		
												   						   
	
	sbox_gen: for i in 0 to n/AES_SBOX_SIZE - 1  generate
	sbox	: aes_sbox 	generic map (rom_style=>rom_style)
			port map (	 
				input=>shiftout(AES_SBOX_SIZE*i + 7 downto AES_SBOX_SIZE*i), 
				output=>subbyte_out(AES_SBOX_SIZE*i+7 downto AES_SBOX_SIZE*i));	
	end generate;	
	   
	mc:
		entity work.groestl_mixbytes(groestl_mixbytes)	
		generic map (n=>n)
		port map (input=>subbyte_out,  output=>output);			
	
end round3_combinational; 