-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================	   

library ieee;
use ieee.std_logic_1164.all;	   
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.sha3_blake_package.all;
            
entity permute8xor is
	generic (			
	h : integer := 256;
	b : integer := 512;
	iw : integer := 32 );
	port(			  	
		clk : in std_logic;		
		m		:	in std_logic_vector(b-1 downto 0);
		em			: in std_logic;
		round		:	in std_logic_vector(3 downto 0);
		consout		:	out std_logic_vector(b-1 downto 0)
	);
end permute8xor;		  

architecture muxbased of permute8xor is	 
	type std_logic_matrix is array (15 downto 0) of std_logic_vector(iw - 1 downto 0) ;
	function wordmatrix2blk  	(x : std_logic_matrix) return std_logic_vector is
		variable retval : std_logic_vector(b-1 downto 0);
	begin
		for i in 0 to 15 loop
			retval(iw*(i+1) - 1 downto iw*i) := x(15-i);
		end loop;
		return retval;
	end wordmatrix2blk;
	function blk2wordmatrix  	(x : std_logic_vector ) return std_logic_matrix is
		variable retval : std_logic_matrix;
	begin
		for i in 0 to 15 loop
		retval(15-i) := x(iw*(i+1) - 1 downto iw*i);
		end loop;
		return retval;
	end blk2wordmatrix;		  
	
	function get_zero_matrix return std_logic_matrix is
		variable ret : std_logic_matrix;
	begin
		for i in 0 to 7 loop
			ret(0) := (others => '0');
		end loop;
		return ret;
	end function get_zero_matrix;  
	constant zero : std_logic_matrix := get_zero_matrix;
	constant consin : std_logic_vector(b-1 downto 0) := get_cons( h, b, iw );
	
	signal mblk, consblk  : std_logic_matrix;
	type block_array is array(0 to 9) of std_logic_matrix;
	signal mblkprime, consblkprime : block_array; 
	signal round_sel : std_logic_vector(3 downto 0);   
	signal mprime_tmp, consprime_tmp, consout_tmp : std_logic_matrix;	
	
begin		
	mblk <= blk2wordmatrix( m );
	consblk <= blk2wordmatrix( consin );
	
	ret1_gen : for i in 0 to 9 generate
		ret2_gen : for j in 0 to 15 generate	 	
			mblkprime(i)(j) 	<= mblk( permute_array( i, j ) );
			consblkprime(i)(j) 	<= consblk( permute_array( i, j ) );
		end generate;
	end generate; 
	
	
	round_sel <= "1001" when em = '1' else round;
	with round_sel select 
	mprime_tmp	 <= mblkprime(1) when "0000",
					mblkprime(2) when "0001",
					mblkprime(3) when "0010",
					mblkprime(4) when "0011",
					mblkprime(5) when "0100",
					mblkprime(6) when "0101",
					mblkprime(7) when "0110",
					mblkprime(8) when "0111",
					mblkprime(9) when "1000",
					mblkprime(0) when "1001",
					mblkprime(1) when "1010",
					mblkprime(2) when "1011",
					mblkprime(3) when "1100",	
					mblkprime(4) when "1101",	
					mblkprime(5) when "1110",	
					mblkprime(6) when "1111",	
					zero when  others ;
				
	with round_sel select 
	consprime_tmp <= 	consblkprime(1) when "0000",
					consblkprime(2) when "0001",
					consblkprime(3) when "0010",
					consblkprime(4) when "0011",
					consblkprime(5) when "0100",
					consblkprime(6) when "0101",
					consblkprime(7) when "0110",
					consblkprime(8) when "0111",
					consblkprime(9) when "1000",
					consblkprime(0) when "1001",	
					consblkprime(1) when "1010",
					consblkprime(2) when "1011",
					consblkprime(3) when "1100",	
					consblkprime(4) when "1101",	
					consblkprime(5) when "1110",	
					consblkprime(6) when "1111",	
					zero when  others ;
	
	
	output_gen : for i in 0 to 7 generate
		consout_tmp(i*2) 	<= mprime_tmp(i*2) xor consprime_tmp(i*2+1);
		consout_tmp(i*2+1) 	<= mprime_tmp(i*2+1) xor consprime_tmp(i*2);
	end generate;
	
	anotherinreg : process ( clk )
	begin
		if rising_edge( clk ) then	 
			consout <= wordmatrix2blk( consout_tmp );
		end if;
	end process;  
	
end muxbased;	

-------------------------------------------
-------------------------------------------
-------------------------------------------
-------------------------------------------	 

library ieee;
use ieee.std_logic_1164.all;	   
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.sha3_blake_package.all;
            
entity permute4xor is
	generic ( 
	h : integer := 256;
	b : integer := 512;	
	iw : integer := 32 );
	port(		
		clk 		: in std_logic;		
		m			:	in std_logic_vector(b-1 downto 0);
		em			: in std_logic;
		round		:	in std_logic_vector(4 downto 0);
		consout		:	out std_logic_vector(b/2-1 downto 0)
	);
end permute4xor;	

architecture muxbased of permute4xor is	 
	type std_logic_matrix is array (15 downto 0) of std_logic_vector(iw - 1 downto 0) ;
	type std_logic_half_matrix is array (7 downto 0) of std_logic_vector(iw - 1 downto 0) ;
	--------------------------
	function wordmatrix2halfblk  	(x : std_logic_half_matrix) return std_logic_vector is
		variable retval : std_logic_vector(b/2-1 downto 0);
	begin
		for i in 0 to 7 loop
			retval(iw*(i+1) - 1 downto iw*i) := x(7-i);
		end loop;
		return retval;
	end wordmatrix2halfblk;
	--------------------------
	function blk2wordmatrix  	(x : std_logic_vector ) return std_logic_matrix is
		variable retval : std_logic_matrix;
	begin
		for i in 0 to 15 loop
			retval(15-i) := x(iw*(i+1) - 1 downto iw*i);
		end loop;
		return retval;
	end blk2wordmatrix;
	-------------------------- 
	
	signal mblk : std_logic_matrix;	
	signal minblkprime : std_logic_half_matrix;

	type block_array is array(0 to 19) of std_logic_half_matrix;
	signal mblkprime : block_array; 
	
	signal round_sel : std_logic_vector(4 downto 0);   
	
	signal mprime_tmp, consprime_tmp, consout_tmp : std_logic_half_matrix;	
	
	function get_halfmatrixzero return std_logic_half_matrix is
		variable ret : std_logic_half_matrix;
	begin
		for i in 0 to 7 loop
			ret(0) := (others => '0');
		end loop;
		return ret;
	end function get_halfmatrixzero;  
	constant zero : std_logic_half_matrix := get_halfmatrixzero;
	--------------------------								   
	constant consin : std_logic_vector(b-1 downto 0) := get_cons( h, b, iw );
	function get_cp ( gsize : integer; iw : integer ) return block_array is
		variable cblk : std_logic_matrix;   									   		
		variable cpblk : block_array;	   
								  
	begin							   
		for i in 0 to 15 loop
			cblk(15-i) := consin(iw*(i+1) - 1 downto iw*i);
		end loop;
		for i in 0 to 9 loop
			for j in 0 to 16/(8/gsize)-1 loop
				cpblk(2*i)(j) 	:= cblk( permute_array( i, j ) );
				cpblk(2*i+1)(j) := cblk( permute_array( i, j+8 ) );
			end loop;
		end loop;		
		return cpblk;
	end function get_cp;		
	------------------------------
	
	constant consblkprime : block_array := get_cp( 4, iw );	  
begin		
	mblk <= blk2wordmatrix( m );
	
	ret1_gen : for i in 0 to 9 generate
		ret2_gen : for j in 0 to 7 generate	 	
			mblkprime(2*i)(j) 		<= mblk( permute_array( i, j ) );
			mblkprime(2*i+1)(j) 	<= mblk( permute_array( i, j+8 ) );
		end generate;
	end generate; 

	round_sel <= "10011" when em = '1' else round;	
	with round_sel select 
	mprime_tmp	 <= 	mblkprime(1) 	when "00000",
						mblkprime(2)  	when "00001",
						mblkprime(3)  	when "00010",
						mblkprime(4)  	when "00011",
						mblkprime(5)  	when "00100",
						mblkprime(6)  	when "00101",
						mblkprime(7)  	when "00110",
						mblkprime(8)  	when "00111",
						mblkprime(9)  	when "01000",
						mblkprime(10)  when "01001",
						mblkprime(11)  when "01010",
						mblkprime(12)  when "01011",
						mblkprime(13)  when "01100",	
						mblkprime(14)  when "01101",	
						mblkprime(15)  when "01110",	
						mblkprime(16)  when "01111",	
						mblkprime(17)  when "10000",	
						mblkprime(18)  when "10001",	
						mblkprime(19)  when "10010",	
						mblkprime(0)   when "10011",	
						mblkprime(1)   when "10100",	
						mblkprime(2)   when "10101",	
						mblkprime(3)   when "10110",	
						mblkprime(4)   when "10111",	
						mblkprime(5)   when "11000",	
						mblkprime(6)   when "11001",	
						mblkprime(7)   when "11010",
						mblkprime(8)  	when "11011",
						mblkprime(9)  	when "11100",
						mblkprime(10)  	when "11101",
						mblkprime(11) 	when "11110",
						mblkprime(12) 	when "11111",						
						zero when  others ;
	
	with round_sel select 
	consprime_tmp	 <= consblkprime(1) 	when "00000",
						consblkprime(2)  	when "00001",
						consblkprime(3)  	when "00010",
						consblkprime(4)  	when "00011",
						consblkprime(5)  	when "00100",
						consblkprime(6) 	when "00101",
						consblkprime(7)  	when "00110",
						consblkprime(8)  	when "00111",
						consblkprime(9)  	when "01000",
						consblkprime(10)  	when "01001",
						consblkprime(11)  	when "01010",
						consblkprime(12)  	when "01011",
						consblkprime(13)  	when "01100",	
						consblkprime(14)  	when "01101",	
						consblkprime(15)  	when "01110",	
						consblkprime(16)  	when "01111",	
						consblkprime(17)  	when "10000",	
						consblkprime(18)  	when "10001",	
						consblkprime(19)  	when "10010",	
						consblkprime(0)   	when "10011",	
						consblkprime(1)   	when "10100",	
						consblkprime(2)  	when "10101",	
						consblkprime(3)   	when "10110",	
						consblkprime(4) 	when "10111",	
						consblkprime(5)   	when "11000",	
						consblkprime(6) 	when "11001",	
						consblkprime(7) 	when "11010",	
						consblkprime(8)  	when "11011",
						consblkprime(9)  	when "11100",
						consblkprime(10)  	when "11101",
						consblkprime(11) 	when "11110",
						consblkprime(12) 	when "11111",						
						zero	when  others ;
				
	output_gen : for i in 0 to 3 generate
		consout_tmp(i*2) 	<= mprime_tmp(i*2) xor consprime_tmp(i*2+1);
		consout_tmp(i*2+1) 	<= mprime_tmp(i*2+1) xor consprime_tmp(i*2);
	end generate;
	
	anotherinreg : process ( clk )
	begin
		if rising_edge( clk ) then	 
			consout <= wordmatrix2halfblk( consout_tmp );
		end if;
	end process;  
end muxbased;	



-------------------------------------------
-------------------------------------------
-------------------------------------------
-------------------------------------------	 

library ieee;
use ieee.std_logic_1164.all;	   
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.sha3_blake_package.all;
            
entity permute2xor is
	generic (		  
	h : integer := 256;
	b : integer := 512;	
	iw : integer := 32 );
	port(		
		clk 		: in std_logic;		
		m			:	in std_logic_vector(b-1 downto 0);
		em			: in std_logic;
		round		:	in std_logic_vector(6 downto 0);
		consout		:	out std_logic_vector(b/4-1 downto 0)
	);
end permute2xor;	

architecture muxbased of permute2xor is	 
	type std_logic_matrix is array (15 downto 0) of std_logic_vector(iw - 1 downto 0) ;
	type std_logic_quarter_matrix is array (3 downto 0) of std_logic_vector(iw - 1 downto 0) ;
	--------------------------
	function wordmatrix2quarter	(x : std_logic_quarter_matrix) return std_logic_vector is
		variable retval : std_logic_vector(b/4-1 downto 0);
	begin
		for i in 0 to 3 loop
			retval(iw*(i+1) - 1 downto iw*i) := x(3-i);
		end loop;
		return retval;
	end wordmatrix2quarter;
	--------------------------
	function blk2wordmatrix  	(x : std_logic_vector ) return std_logic_matrix is
		variable retval : std_logic_matrix;
	begin
		for i in 0 to 15 loop
			retval(15-i) := x(iw*(i+1) - 1 downto iw*i);
		end loop;
		return retval;
	end blk2wordmatrix;
	-------------------------- 
	
	signal mblk : std_logic_matrix;	
	signal minblkprime : std_logic_quarter_matrix;

	type block_array is array(0 to 39) of std_logic_quarter_matrix;
	signal mblkprime : block_array; 
	
	signal round_sel : std_logic_vector(5 downto 0);   
	
	signal mprime_tmp, consprime_tmp, consout_tmp : std_logic_quarter_matrix;	
	
	function get_quartermatrixzero return std_logic_quarter_matrix is
		variable ret : std_logic_quarter_matrix;
	begin
		for i in 0 to 3 loop
			ret(0) := (others => '0');
		end loop;
		return ret;
	end function get_quartermatrixzero;  
	constant zero : std_logic_quarter_matrix := get_quartermatrixzero;
	--------------------------								   
	constant consin : std_logic_vector(b-1 downto 0) := get_cons( h, b, iw );
	function get_cp ( iw : integer ) return block_array is
		variable cblk : std_logic_matrix;   									   		
		variable cpblk : block_array;	   
								  
	begin							   
		for i in 0 to 15 loop
			cblk(15-i) := consin(iw*(i+1) - 1 downto iw*i);
		end loop;
		for i in 0 to 9 loop
			for j in 0 to 3 loop
				cpblk(4*i)(j) 	:= cblk( permute_array( i, j*2+1 ) );
				cpblk(4*i+1)(j) := cblk( permute_array( i, j*2 ) );
				cpblk(4*i+2)(j) := cblk( permute_array( i, j*2+9 ) );
				cpblk(4*i+3)(j) := cblk( permute_array( i, j*2+8 ) );
			end loop;
		end loop;		
		return cpblk;
	end function get_cp;		
	------------------------------	
	constant consblkprime : block_array := get_cp( iw );			
begin		
	mblk <= blk2wordmatrix( m );
	
	ret1_gen : for i in 0 to 9 generate
		ret2_gen : for j in 0 to 3 generate	 	
			mblkprime(4*i)(j) 		<= mblk( permute_array( i, j*2 ) );
			mblkprime(4*i+1)(j) 	<= mblk( permute_array( i, j*2+1 ) );
			mblkprime(4*i+2)(j) 	<= mblk( permute_array( i, j*2+8 ) );
			mblkprime(4*i+3)(j) 	<= mblk( permute_array( i, j*2+9) );
		end generate;
	end generate; 

	round_sel <= "100111" when em = '1' else round(5 downto 0);	
	with round_sel select 
	mprime_tmp	 <= 	mblkprime(1)   when "000000",
						mblkprime(2)   when "000001",
						mblkprime(3)   when "000010",
						mblkprime(4)   when "000011",
						mblkprime(5)   when "000100",
						mblkprime(6)   when "000101",
						mblkprime(7)   when "000110",
						mblkprime(8)   when "000111",
						mblkprime(9)   when "001000",
						mblkprime(10)  when "001001",
						mblkprime(11)  when "001010",
						mblkprime(12)  when "001011",
						mblkprime(13)  when "001100",	
						mblkprime(14)  when "001101",	
						mblkprime(15)  when "001110",	
						mblkprime(16)  when "001111",	
						mblkprime(17)  when "010000",	
						mblkprime(18)  when "010001",	
						mblkprime(19)  when "010010",	
						mblkprime(20)  when "010011",
						mblkprime(21)  when "010100",
						mblkprime(22)  when "010101",
						mblkprime(23)  when "010110",
						mblkprime(24)  when "010111",
						mblkprime(25)  when "011000",
						mblkprime(26)  when "011001",
						mblkprime(27)  when "011010",
						mblkprime(28)  when "011011",
						mblkprime(29)  when "011100",
						mblkprime(30)  when "011101",
						mblkprime(31)  when "011110",
						mblkprime(32)  when "011111",
						mblkprime(33)  when "100000",	
						mblkprime(34)  when "100001",	
						mblkprime(35)  when "100010",	
						mblkprime(36)  when "100011",	
						mblkprime(37)  when "100100",	
						mblkprime(38)  when "100101",	
						mblkprime(39)  when "100110",
						mblkprime(0)   when "100111",	
						mblkprime(1)   when "101000",
						mblkprime(2)   when "101001",
						mblkprime(3)   when "101010",
						mblkprime(4)   when "101011",
						mblkprime(5)   when "101100",
						mblkprime(6)   when "101101",
						mblkprime(7)   when "101110",
						mblkprime(8)   when "101111",
						mblkprime(9)   when "110000",
						mblkprime(10)  when "110001",
						mblkprime(11)  when "110010",
						mblkprime(12)  when "110011",
						mblkprime(13)  when "110100",	
						mblkprime(14)  when "110101",	
						mblkprime(15)  when "110110",	
						mblkprime(16)  when "110111",		
						mblkprime(17)  when "111000",	
						mblkprime(18)  when "111001",	
						mblkprime(19)  when "111010",	
						mblkprime(20)  when "111011",
						mblkprime(21)  when "111100",
						mblkprime(22)  when "111101",
						mblkprime(23)  when "111110",
						mblkprime(24)  when "111111",						
						zero when  others ;
	
	with round_sel select 
	consprime_tmp	 <= consblkprime(1)   when "000000",
						consblkprime(2)   when "000001",
						consblkprime(3)   when "000010",
						consblkprime(4)   when "000011",
						consblkprime(5)   when "000100",
						consblkprime(6)   when "000101",
						consblkprime(7)   when "000110",
						consblkprime(8)   when "000111",
						consblkprime(9)   when "001000",
						consblkprime(10)  when "001001",
						consblkprime(11)  when "001010",
						consblkprime(12)  when "001011",
						consblkprime(13)  when "001100",	
						consblkprime(14)  when "001101",	
						consblkprime(15)  when "001110",	
						consblkprime(16)  when "001111",	
						consblkprime(17)  when "010000",	
						consblkprime(18)  when "010001",	
						consblkprime(19)  when "010010",	
						consblkprime(20)  when "010011",
						consblkprime(21)  when "010100",
						consblkprime(22)  when "010101",
						consblkprime(23)  when "010110",
						consblkprime(24)  when "010111",
						consblkprime(25)  when "011000",
						consblkprime(26)  when "011001",
						consblkprime(27)  when "011010",
						consblkprime(28)  when "011011",
						consblkprime(29)  when "011100",
						consblkprime(30)  when "011101",
						consblkprime(31)  when "011110",
						consblkprime(32)  when "011111",
						consblkprime(33)  when "100000",	
						consblkprime(34)  when "100001",	
						consblkprime(35)  when "100010",	
						consblkprime(36)  when "100011",	
						consblkprime(37)  when "100100",	
						consblkprime(38)  when "100101",	
						consblkprime(39)  when "100110",
						consblkprime(0)   when "100111",	
						consblkprime(1)   when "101000",
						consblkprime(2)   when "101001",
						consblkprime(3)   when "101010",
						consblkprime(4)   when "101011",
						consblkprime(5)   when "101100",
						consblkprime(6)   when "101101",
						consblkprime(7)   when "101110",
						consblkprime(8)   when "101111",
						consblkprime(9)   when "110000",
						consblkprime(10)  when "110001",
						consblkprime(11)  when "110010",
						consblkprime(12)  when "110011",
						consblkprime(13)  when "110100",	
						consblkprime(14)  when "110101",	
						consblkprime(15)  when "110110",	
						consblkprime(16)  when "110111",		
						consblkprime(17)  when "111000",	
						consblkprime(18)  when "111001",	
						consblkprime(19)  when "111010",	
						consblkprime(20)  when "111011",
						consblkprime(21)  when "111100",
						consblkprime(22)  when "111101",
						consblkprime(23)  when "111110",
						consblkprime(24)  when "111111",											
						zero when  others ;
				
	output_gen : for i in 0 to 3 generate
		consout_tmp(i) 	<= mprime_tmp(i) xor consprime_tmp(i);
	end generate;
	
	anotherinreg : process ( clk )
	begin
		if rising_edge( clk ) then	 
			consout <= wordmatrix2quarter( consout_tmp );
		end if;
	end process;  
end muxbased;	