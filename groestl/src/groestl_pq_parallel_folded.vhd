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

entity groestl_pq_parallel_folded is
generic (
	n:integer := GROESTL_DATA_SIZE_SMALL; 
	rom_style : integer := DISTRIBUTED; 
	FF : integer := 2;
	p_mode : integer := 1);
port( 					
	clk, rst		: in std_logic;
	stateEnable		: in std_logic;
	shiftEnable		: in std_logic;					  
	sel				: in std_logic_vector(log2(ff)-1 downto 0);
	round			: in std_logic_vector(7 downto 0);
	input 			: in std_logic_vector(n-1 downto 0);
   	output 			: out std_logic_vector(n-1 downto 0));
end groestl_pq_parallel_folded;  		

architecture round3 of groestl_pq_parallel_folded is
	signal shiftout		: std_logic_vector(n-1 downto 0);
	signal addcons		: std_logic_vector(n-1 downto 0);
	signal stateOutReg	: std_logic_vector(n-1 downto 0);
	
	signal subbyte_out	: std_logic_vector(n/FF-1 downto 0);
	signal mux			: std_logic_vector(n/FF-1 downto 0);	 
	signal mixbytesOut	: std_logic_vector(n/FF-1 downto 0);		 
	signal shfReg		: std_logic_vector(N-N/FF-1 downto 0);
	constant zero : std_logic_vector(n-1 downto 0) := (others => '0');
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
		
	StateReg: regn
		generic map(N=>n, init=>zero(n-1 downto 0))
		port map   (clk => clk, rst => rst, en => stateEnable, input => shiftout, output => stateOutReg ); 
		
												   						   
	FoldX2Gen: if FF = 2 generate
		--mux <= stateOutReg(n-1 downto n/2) when sel(0) = '1' else stateOutReg(n/2-1 downto 0);
		mux <= stateOutReg(n-1 downto n/2) when sel(0) = '0' else stateOutReg(n/2-1 downto 0);
	end generate;
	FoldX4Gen: if FF = 4 generate
		with sel(1 downto 0) select
		mux <= 	stateOutReg(n-1 	downto n*3/4) when "00",
				stateOutReg(n*3/4-1 downto n*2/4) when "01",
				stateOutReg(n*2/4-1 downto   n/4) when "10",
				stateOutReg(n/4-1 	downto 	   0) when others;	
	end generate;
	FoldX8Gen: if ff = 8 generate
		with sel(2 downto 0) select
		mux <= 	stateOutReg(n-1 	downto n*7/8) when "000",
				stateOutReg(n*7/8-1 downto n*6/8) when "001",
				stateOutReg(n*6/8-1 downto n*5/8) when "010",
				stateOutReg(n*5/8-1 downto n*4/8) when "011",
				stateOutReg(n*4/8-1 downto n*3/8) when "100",
				stateOutReg(n*3/8-1 downto n*2/8) when "101",
				stateOutReg(n*2/8-1 downto   n/8) when "110",
				stateOutReg(n/8-1 	downto 	   0) when others;
	end generate;
	
	sbox_gen: for i in 0 to (n/ff)/AES_SBOX_SIZE - 1  generate
		sbox: 
			aes_sbox 	
			generic map (rom_style=>rom_style)
			port map (input=>mux(AES_SBOX_SIZE*i + 7 downto AES_SBOX_SIZE*i), 
					 output=>subbyte_out(AES_SBOX_SIZE*i+7 downto AES_SBOX_SIZE*i));	
	end generate;	
	   
	mc:
		entity work.groestl_mixbytes(groestl_mixbytes)	
		generic map (n=>n/ff)
		port map (input=>subbyte_out,  output=>mixbytesOut);	
	
	FoldX2RegGen: if FF = 2 generate
		StateReg: regn
			generic map(N=>N/FF, init=>zero(N/FF-1 downto 0))
			port map   (clk => clk, rst => rst, en => shiftEnable, input => mixbytesOut, output => shfReg ); 
	end generate;
	FoldXXRegGen: if FF > 2 generate
		ShfinGen : 
			sipo
			generic map ( N => N-N/FF, M =>N/FF)
			port map (clk => clk, en => shiftEnable, input => mixbytesOut, output => shfReg );
	end generate;
	
		
	output <= shfReg & mixbytesOut;
end round3; 