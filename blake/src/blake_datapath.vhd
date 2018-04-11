-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.sha3_blake_package.ALL;
use work.sha3_pkg.all;

entity blake_datapath is	 	
	generic (	  	   
		FF : integer := 8;
		BS : integer := 512;
		W : integer := 64;
		IW : integer := 32;
		HS : integer := 256;
		ADDERTYPE : integer := SCCA_BASED);
	port (
		-- external
		rst : in std_logic;
		clk : in std_logic;
		din  : in std_logic_vector(W-1 downto 0);	
		dout : out std_logic_vector(W-1 downto 0);	
		
		--fsm 1		
		ein : in std_logic;
		ec, lc, lm : in std_logic;	
		zc1, zc0 : out std_logic;
		dt, eth, etl,sel_t : in std_logic;
		
		-- pad
		last_word : in std_logic;
		en_lb, clr_lb : in std_logic; -- decrement last block word count ... rem1_reg
		sel_pad : in std_logic_vector(HS/256-1 downto 0);
		spos : in std_logic_vector(1 downto 0);	 
		comp_rem_e0, comp_lb_e0, comp_rem_mt440 : out std_logic; 
		
		--fsm 2			  		
		slr : in std_logic;						
		round : in std_logic_vector(3+FF-1 downto 0);				
		er, em : in std_logic;
		sf : in std_logic;
		lo : in std_logic;	  		
		
		--fsm 3
		eo : in std_logic
	);				  
end blake_datapath;

architecture struct of blake_datapath is   
	constant mw 			: integer := BS;		 
	constant bseg			: integer := BS/W;		  
	constant log2b			: integer := log2( BS );
	constant log2bzeros		: std_logic_vector(log2b-1 downto 0) := (others => '0');	
	constant bzeros			: std_logic_vector(BS-1 downto 0) := (others => '0');
	constant bhalfzeros		: std_logic_vector(BS/2-1 downto 0) := (others => '0');
	constant bmin	        : integer := BS - 2 - IW*2;
	constant iv : std_logic_vector(BS/2-1 downto 0) := get_iv( HS, IW );
    constant cons : std_logic_vector(BS-1 downto 0) := get_cons( HS, BS, IW );
    constant counterzeros   : std_logic_vector(2*IW-log2b-1 downto 0) := (others => '0');
	constant msg_cntr_size  : integer := 16;
    
	signal hinit, rdprime, rmux : std_logic_vector(BS/2 - 1 downto 0);
	signal rinit, rin, r, rprime : std_logic_vector(BS-1 downto 0);	
	signal min : std_logic_vector(BS-W-1 downto 0);
	signal mreg_in, m : std_logic_vector(BS-1 downto 0);
	signal consout : std_logic_vector(IW*2*(8/FF)-1 downto 0);
	signal eout, eh : std_logic;	  	 
	signal c_s : std_logic_vector(15 downto 0);
	
	type std_logic_matrix is array (natural range <>) of std_logic_vector(IW - 1 downto 0) ;
	function wordmatrix2blk  	(x : std_logic_matrix) return std_logic_vector is
		variable retval : std_logic_vector(BS-1 downto 0);
	begin
		for i in 0 to 15 loop
			retval(IW*(i+1) - 1 downto IW*i) := x(15-i);
		end loop;
		return retval;
	end wordmatrix2blk;
	function blk2wordmatrix  	(x : std_logic_vector; blksize : integer ) return std_logic_matrix is
		variable retval : std_logic_matrix(0 to blksize-1);
	begin
		for i in 0 to blksize-1 loop
			retval(blksize-1-i) := x(IW*(i+1) - 1 downto IW*i);
		end loop;
		return retval;
	end blk2wordmatrix;	
		
	signal v1, v2, v2_perm, v2_revert, v3 : std_logic_matrix( 0 to 15 ); 
	signal cp : std_logic_matrix(0 to 16/(FF) - 1);	 
	
	type bot_permute_type is array ( 0 to 15 ) of integer;
	constant bot_permute : bot_permute_type := ( 0,1,2,3,5,6,7,4,10,11,8,9,15,12,13,14 );
	
	signal t_top : std_logic_vector(2*IW-log2b-1 downto 0);
	signal t_bot, t_bot_enabled : std_logic_vector(log2b-1 downto 0);
	signal t, t_original : std_logic_vector(2*IW-1 downto 0);			   
	
	constant zeros : std_logic_vector(63 downto 0) := (others => '0');
	constant additional_bit : integer := HS/256-1;
	signal remaining_bits : std_logic_vector(8+additional_bit downto 0);
	signal din_padded : std_logic_vector(W-1 downto 0);
	signal sel_pad_location_lookup, sel_din_lookup : std_logic_vector( 7 downto 0 ); 	
	signal sel_din, sel_pad_location : std_logic_vector(7 downto 0);		  
	signal din_or_length : std_logic_vector(w-1 downto 0);
	-- debug			  
	-- signal rinit_m, r_m, cp_m : std_logic_matrix(0 to 15);	
begin		
	-- debug
	-- rinit_m <= blk2wordmatrix( rin, 16 );		 
	-- r_m <= blk2wordmatrix( r, 16 );	
	--				
	
	-- Segment counter
	decounter_gen : decountern generic map ( N => msg_cntr_size, sub => 1 ) port map ( clk => clk, rst => '0', load => lc, en => ec, input => din(log2b+msg_cntr_size-1 downto log2b), output => c_s );
	zc0 <= '1' when (c_s = 0) else '0'; 	
	zc1 <= '1' when (c_s = 1) else '0';
	
	-- padding unit
	rem1_gen : decountern 
		generic map ( N => 3 + additional_bit, sub => 1 ) 
		port map ( clk => clk, rst => clr_lb, load => lc, en => en_lb, input => din(8 + additional_bit downto 6), output => remaining_bits(8 + additional_bit downto 6));	
	rem2_reg : regn generic map ( N => 6, init => "000000" ) 
		port map ( clk => clk, rst => clr_lb, en => lc, input => din(5 downto 0), output => remaining_bits(5 downto 0));		 	
	comp_rem_e0 <= '1' when remaining_bits = 0 else '0';
	comp_lb_e0 <= '1' when remaining_bits(8+additional_bit downto 6) = zeros(2+additional_bit downto 0) else '0';	   
	
	sel_pad_location_lookup <= lookup_sel_lvl2_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_pad_location <= (others => '0') when spos(0) = '0' else sel_pad_location_lookup;
	
	sel_din_lookup <= lookup_sel_lvl1_64bit_pad(conv_integer(remaining_bits(5 downto 3)));	
	sel_din <= (others => '1') when spos(1) = '1' else sel_din_lookup;

	byte_pad_gen : entity work.blake_bytepad(struct) 
		generic map ( w => 64 ) 
		port map ( din => din, dout => din_padded, sel_pad_location => sel_pad_location, sel_din =>  sel_din, last_word => last_word);																																 
																																	 																														 
	h256_gen : if HS = 256 generate
		din_or_length <= din_padded when sel_pad(0) = '0' else t_original(63 downto 0);
		comp_rem_mt440 <= '1' when remaining_bits > 440 else '0';
	end generate;
	h512_gen : if HS = 512 generate
		with sel_pad(1 downto 0) select
		din_or_length <= t_original(63 downto 0) when "11",
						t_original(127 downto 64) when "10",
						din_padded when others;
		comp_rem_mt440 <= '1' when remaining_bits > 888 else '0';
	end generate;	

	-- LEN counter 
	th_gen : countern generic map ( N => 2*iw-log2b, step => 1 ) port map ( clk => clk, rst => dt, load => '0', en => eth, input => conv_std_logic_vector(0,2*iw-log2b), output => t_top );
	tl_gen : regn generic map ( N => log2b, init => log2bzeros ) port map ( clk => clk, rst => dt, en => etl, input => remaining_bits(log2b-1 downto 0), output => t_bot );	
	t_original <= t_top & t_bot ;
	t <= t_original when sel_t = '0' else (others => '0');

	--  input / permutation
	shfin_gen : sipo generic map ( N => (mw-W),M =>W) port map (clk => clk, en => ein, input => din_or_length, output => min );   
	mreg_in <= min & din_or_length;
	mreg : regn generic map (N => mw, init => bzeros) port map (clk => clk, rst => '0', en => lm, input => mreg_in, output => m );

	rmux <= iv when sf = '1' else rdprime;

	rinit <= rmux &  cons(BS-1 downto BS-IW*4)  & 
			(t(IW-1 downto 0) xor cons(BS-1-IW*4 downto BS-IW*5)) &  (t(IW-1 downto 0) xor cons(BS-IW*5-1 downto BS-IW*6)) &
			(t(2*IW-1 downto IW) xor cons(BS-1-IW*6 downto BS-IW*7))  & (t(2*IW-1 downto IW) xor cons(BS-IW*7-1 downto BS-IW*8));
	
	eh <= sf or slr;
	hreg_gen : regn generic map ( N => BS/2, init => bhalfzeros ) port map (clk => clk, rst => '0', en => eh, input => rmux, output => hinit );	
	
	rin <= rinit when (sf = '1' or slr = '1' ) else rprime;
	r_gen : regn generic map ( N => BS, init => bzeros ) port map (clk => clk, rst => '0', en => er, input => rin, output => r );		
	
	Core8Gen : if FF = 1 generate	
		perm8_gen : entity work.permute8xor(muxbased) 
			generic map (h => HS, b => BS, IW => IW) 
			port map ( clk => clk,  em => em, m => m, round => round, consout => consout );
				
		v1 <= blk2wordmatrix(r, 16);
		cp <= blk2wordmatrix(consout, 16);
		
		glvl1 : for i in 0 to 3 generate
			g0123 : entity work.gfunc_modified(struct) 	generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
				port map ( ain => v1(i),bin => v1(i+4),cin => v1(i+8),din => v1(i+12),
					  const_0 => cp(2*i),const_1 => cp(2*i + 1),
					  aout =>  v2(i), bout => v2(i+4), cout=> v2(i+8),dout => v2(i+12));
		end generate;
		
		g4 : entity work.gfunc_modified(struct) generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
		   port map ( ain => v2(0),bin => v2(5),cin => v2(10),din => v2(15),
					  const_0 => cp(8),const_1 => cp(9),
					  aout =>  v3(0), bout => v3(5), cout=> v3(10),dout => v3(15));
														 
		g5 : entity work.gfunc_modified(struct) generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
		   port map ( ain => v2(1),bin => v2(6),cin => v2(11),din => v2(12),
					 const_0 => cp(10),const_1 => cp(11),
					  aout =>  v3(1), bout => v3(6), cout=> v3(11),dout => v3(12));
	
		g6 : entity work.gfunc_modified(struct) generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
 		   port map ( ain => v2(2),bin => v2(7),cin => v2(8),din => v2(13),
					  const_0 => cp(12),const_1 => cp(13),
					  aout =>  v3(2), bout => v3(7), cout=> v3(8),dout => v3(13));
	
		g7 : entity work.gfunc_modified(struct) generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
		   port map ( ain => v2(3),bin => v2(4),cin => v2(9),din => v2(14),
					  const_0 => cp(14),const_1 => cp(15),
					  aout =>  v3(3), bout => v3(4), cout=> v3(9),dout => v3(14));
						  
		rprime <= wordmatrix2blk(v3);
	end generate;
	
	Core4Gen : if FF = 2 generate
		v1 <= blk2wordmatrix(r, 16);
		perm4_gen : entity work.permute4xor(muxbased) 
			generic map (h => HS, b => BS, IW => IW) 
			port map ( clk => clk,  em => em, m => m, round => round, consout => consout );

		cp <= blk2wordmatrix(consout, 8);
		glvl1 : for i in 0 to 3 generate
			g0123 : entity work.gfunc_modified(struct) 	generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
							port map ( ain => v1(i),bin => v1(i+4),cin => v1(i+8),din => v1(i+12),
								  const_0 => cp(2*i),const_1 => cp(2*i + 1),
								  aout =>  v2(i), bout => v2(i+4), cout=> v2(i+8),dout => v2(i+12));
		end generate;
		
		v2_gen : for i in 0 to 15 generate
			v2_perm( bot_permute(i) ) <= v2( i ); 
			v2_revert( i ) <= v2( bot_permute(i) );
		end generate;
		
		v3 <= v2_perm when round(0) = '1' else v2_revert;
			
		rprime <= wordmatrix2blk(v3);
		
	end generate;	  
	
	Core2Gen : if FF = 4 generate	  											  	
		v1 <= blk2wordmatrix(r, 16);
		perm4_gen : entity work.permute2xor(muxbased) 
			generic map ( h=> HS, b => BS, IW => IW) 
			port map ( clk => clk,  em => em, m => m, round => round, consout => consout );

		cp <= blk2wordmatrix(consout, 4);
		glvl1 : for i in 0 to 3 generate
			g0123 : entity work.gfunc_half_modified(struct) 	generic map ( IW => IW, h => HS, ADDER_TYPE => ADDERTYPE )
							port map ( ain => v1(i),bin => v1(i+4),cin => v1(i+8),din => v1(i+12),
								  const => cp(i), sel => round(0),
								  aout =>  v2(i), bout => v2(i+4), cout=> v2(i+8),dout => v2(i+12));
		end generate;
		
		v2_gen : for i in 0 to 15 generate
			v2_revert( bot_permute(i) ) <= v2( i ); 
			v2_perm( i ) <= v2( bot_permute(i) );	
		end generate;								
		
		with round(1 downto 0) select
		v3 <= 	v2_perm when "01",
				v2_revert when "11",
				v2 when others;
			
		rprime <= wordmatrix2blk(v3);	
	end generate;
	
	--finalization				
	rdprime <= hinit xor r(BS-1 downto BS/2) xor r(BS/2-1 downto 0);
	
	--output	 								
	eout <= eo or lo;
	shfout_gen : piso generic map ( N => HS, M => W ) port map (clk => clk, sel => lo, en => eout, input => rdprime, output => dout );		
end struct;