-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.sha3_jh_package.all;
use work.sha3_pkg.all;

entity jh_datapath_mem is	
	generic ( h : integer := 256; UF : integer := 1);
	port (
		-- external
		clk : in std_logic;
		din  : in std_logic_vector(w-1 downto 0);	
		dout : out std_logic_vector(w-1 downto 0);	
		
        -- pad
		sel_pad : in std_logic_vector(1 downto 0);
		rst_size, en_size : in std_logic;
        en_lb, clr_lb : in std_logic; -- decrement last block word count ... rem1_reg
        comp_rem_e0, comp_lb_e0 : out std_logic;
        spos : in std_logic_vector(1 downto 0);
        
		--fsm 1		
		ein : in std_logic;
		ec, lc : in std_logic;			
		zc0 : out std_logic;				  
		
		--fsm 2			  		
		round : in std_logic_vector(5-(UF-1) downto 0);
		er : in std_logic;
		sf : in std_logic;
		lo : in std_logic;
		
		srdp : in std_logic;		
		
		--fsm 3
		eout : in std_logic
	);				  
end jh_datapath_mem;


architecture struct of jh_datapath_mem is 
	-- msg counter size : max is (w-log2mw-1)
	constant c_counter_size : integer := 16;
	
	--input		  
	signal min, min_out : std_logic_vector(mw-1 downto 0);
		
    -- round constant
	type crd_out_ux_type is array (0 to UF-1) of std_logic_vector(crw-1 downto 0);
	signal crd_out, crd_out_pre : crd_out_ux_type;
	
	-- round		
	type rd_out_ux_type is array (0 to UF-1) of std_logic_vector(b-1 downto 0);
	signal rd_out : rd_out_ux_type;
	
	
	signal g, dg : std_logic_vector(b-1 downto 0);
	signal rin, rout : std_logic_vector(b-1 downto 0);
	signal hp, hm : std_logic_vector(b-1 downto 0);
	signal hp_or_iv : std_logic_vector(b-1 downto 0);
	signal c : std_logic_vector(c_counter_size-1 downto 0);		   
	signal remaining_bits : std_logic_vector(8 downto 0);
	
	constant iv : std_logic_vector(b-1 downto 0) := get_iv( h );
	signal din_padded : std_logic_vector(w-1 downto 0);
	signal sel_pad_location_lookup, sel_din_lookup : std_logic_vector( 7 downto 0 ); 	
	signal sel_pad_location, sel_din : std_logic_vector(7 downto 0);
	-- debug  						   
--	 signal crdo : std_logic_vector(b-1 downto 0);
--	 constant zeros : std_logic_vector(b-1-crw downto 0) := (others => '0');
--	 signal dg_m, rin_m, rout_m, rd_out_m, crd_out_m, hm_m, hp_m : std_logic_matrix;
begin						
	---//////////////---
	-- block decounter																									   	
	decounter_gen : decountern generic map ( N => c_counter_size, sub => 1 ) port map ( clk => clk, rst => '0', load => lc, en => ec, input => din(c_counter_size+log2mw-1 downto log2mw), output => c);	
	zc0 <= '1' when c = 0 else '0';

	-- padding unit
	rem1_gen : decountern 
		generic map ( N => 3, sub => 1 ) 
		port map ( clk => clk, rst => clr_lb, load => lc, en => en_lb, input => din(8 downto 6), output => remaining_bits(8 downto 6));	
	rem2_reg : regn generic map ( N => 6, init => "000000" ) 
		port map ( clk => clk, rst => clr_lb, en => lc, input => din(5 downto 0), output => remaining_bits(5 downto 0));	
	
	sel_pad_location_lookup <= lookup_sel_lvl2_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_pad_location <= (others => '0') when spos(0) = '0' else sel_pad_location_lookup;
	
	sel_din_lookup <= lookup_sel_lvl1_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_din <= (others => '1') when spos(1) = '1' else sel_din_lookup;
					
	comp_rem_e0 <= '1' when remaining_bits = 0 else '0';
	comp_lb_e0 <= '1' when remaining_bits(8 downto 6) = "000" else '0';
	
	pad_unit : entity work.jh_byte_pad(struct)
		port map (						
		din => din, dout => din_padded, sel_pad => sel_pad, sel_pad_location => sel_pad_location, sel_din => sel_din,
		clk => clk, rst => rst_size, en_size => en_size );
			
	-- input
	shfin_gen : sipo generic map ( N => mw,M => w) port map (clk => clk, en => ein, input => din_padded, output => min );
	-- input register (for xor at the last round of a block )
	min_reg : regn generic map ( N => mw, init => mwzeros ) port map ( clk => clk, rst => '0', en => srdp, input => min, output => min_out );
	-- input to r reg
	hm <= ( min xor hp_or_iv(b-1 downto b/2) ) & hp_or_iv(b/2-1 downto 0);	
	hp_or_iv <= iv when sf = '1' else hp;	
	
	-- group (rearrange them into correct order)		   
	g <= form_group( hm, b, crw );
	rin <= g when srdp = '1' else rd_out(UF-1);

	--R registers
	rreg_gen : regn generic map ( N => b, init => bzeros ) port map ( clk => clk, rst => '0', en => er, input => rin, output => rout );		
		
	-- output to round function	 
	dg <= degroup( rout, b, crw );
 	hp <= dg(b-1 downto b/2) & ( min_out xor dg(b/2-1 downto 0) );
	
	-- output 
	shfout_gen : piso generic map ( N => h, M => w ) port map (clk => clk, sel => lo, en => eout, input => hp(h-1 downto 0), output => dout );		

	--- ////////////////////////////////////
	-- round constant (generate using generator)	
		
	uu1: process ( clk ) 
	begin
		if rising_edge( clk ) then
			crd_out <= crd_out_pre;
		end if;			
	end process;	 
	
	
	UF1 : if UF=1 generate
		-- RC 
		crd_out_pre(0) <= rc_cons( conv_integer(round));
		-- ROUND
		rd_gen 	: entity work.jh_rd(struct) generic map ( bw => b, cw => crw  ) port map ( input => rout, cr => crd_out(0), output => rd_out(0) );
	end generate;
		
	UF2 : if UF=2 generate
		-- RC 
		crd_out_pre(0) <= rc_cons_half(0, conv_integer(round));
		crd_out_pre(1) <= rc_cons_half(1, conv_integer(round));
		-- ROUND
		rd1_gen 	: entity work.jh_rd(struct) generic map ( bw => b, cw => crw  ) port map ( input => rout, cr => crd_out(0), output => rd_out(0) );
		rd2_gen 	: entity work.jh_rd(struct) generic map ( bw => b, cw => crw  ) port map ( input => rd_out(0), cr => crd_out(1), output => rd_out(1) );
	end generate;
	
	--	--debug
--	 rin_m <= blk2wordmatrix_inv( rin );
--	 rout_m <= blk2wordmatrix_inv( rout );
--	 rd_out_m <= blk2wordmatrix_inv( rd_out );
--		dg_m <= blk2wordmatrix_inv( dg );
--		hp_m <= blk2wordmatrix_inv( hp );
--		hm_m <= blk2wordmatrix_inv( hm );
--	 crdo <= crd_out & zeros;
--	 crd_out_m <= blk2wordmatrix_inv( crdo );
end struct;		   


-- ===============================
-- ============ RC ON THE FLY ===================
-- ===============================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.sha3_jh_package.all;
use work.sha3_pkg.all;

entity jh_datapath_otf is	
	generic ( h : integer := 256; UF : integer := 1 );
	port (
		-- external
		clk : in std_logic;
		din  : in std_logic_vector(w-1 downto 0);	
		dout : out std_logic_vector(w-1 downto 0);		 
		
		 -- pad		
		sel_pad : in std_logic_vector(1 downto 0);
		rst_size, en_size : in std_logic;
        en_lb, clr_lb : in std_logic; -- decrement last block word count ... rem1_reg
        comp_rem_e0, comp_lb_e0 : out std_logic;
        spos : in std_logic_vector(1 downto 0);
		--fsm 1		
		ein : in std_logic;
		ec, lc : in std_logic;	
		zc0 : out std_logic;
		--fsm 2			  		
		erf : in std_logic;
		er : in std_logic;
		sf : in std_logic;
		lo : in std_logic;		
		srdp : in std_logic;		
		
		--fsm 3
		eout : in std_logic
	);				  
end jh_datapath_otf;

architecture struct of jh_datapath_otf is  	
	constant c_counter_size : integer := 16;
	
	--input		  
	signal min, min_out : std_logic_vector(mw-1 downto 0);
	
	-- round constant
	type crd_out_ux_type is array (0 to UF-1) of std_logic_vector(crw-1 downto 0);
	signal crd_out : crd_out_ux_type;
	signal crdp : std_logic_vector(crw-1 downto 0);
	-- round		
	type rd_out_ux_type is array (0 to UF-1) of std_logic_vector(b-1 downto 0);
	signal rd_out : rd_out_ux_type;
	
	
	signal g, dg : std_logic_vector(b-1 downto 0);
	signal rin, rout : std_logic_vector(b-1 downto 0);
	signal hp, hm : std_logic_vector(b-1 downto 0);
	signal hp_or_iv : std_logic_vector(b-1 downto 0);		
	signal c : std_logic_vector(c_counter_size-1 downto 0);	
	constant iv : std_logic_vector(b-1 downto 0) := get_iv( h );
	signal remaining_bits : std_logic_vector(8 downto 0);

	signal din_padded : std_logic_vector(w-1 downto 0);
	signal sel_pad_location_lookup, sel_din_lookup : std_logic_vector( 7 downto 0 ); 	
	signal sel_pad_location, sel_din : std_logic_vector(7 downto 0);
	
	-- debug  						   
--	signal crdo : std_logic_vector(b-1 downto 0);
--	constant zeros : std_logic_vector(b-1-crw downto 0) := (others => '0');
--	signal dg_m, rin_m, rout_m, rd_out_m, crd_out_m, hm_m, hp_m : std_logic_matrix;
begin						
	---//////////////---
	-- block decounter																									   	
	decounter_gen : decountern generic map ( N => c_counter_size, sub => 1 ) port map ( clk => clk, rst => '0', load => lc, en => ec, input => din(c_counter_size+log2mw-1 downto log2mw), output => c);	
	zc0 <= '1' when c = 0 else '0';		
	
	-- padding unit
	rem1_gen : decountern 
		generic map ( N => 3, sub => 1 ) 
		port map ( clk => clk, rst => clr_lb, load => lc, en => en_lb, input => din(8 downto 6), output => remaining_bits(8 downto 6));	
	rem2_reg : regn generic map ( N => 6, init => "000000" ) 
		port map ( clk => clk, rst => clr_lb, en => lc, input => din(5 downto 0), output => remaining_bits(5 downto 0));	
	
	sel_pad_location_lookup <= lookup_sel_lvl2_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_pad_location <= (others => '0') when spos(0) = '0' else sel_pad_location_lookup;
	
	sel_din_lookup <= lookup_sel_lvl1_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_din <= (others => '1') when spos(1) = '1' else sel_din_lookup;
	
	pad_unit : entity work.jh_byte_pad(struct)
		port map (						
		din => din, dout => din_padded, sel_pad => sel_pad, sel_pad_location => sel_pad_location, sel_din => sel_din,
		clk => clk, rst => rst_size, en_size => en_size );
		
	comp_rem_e0 <= '1' when remaining_bits = 0 else '0';
	comp_lb_e0 <= '1' when remaining_bits(8 downto 6) = "000" else '0';
		
	-- input
	shfin_gen : sipo generic map ( N => mw,M => w) port map (clk => clk, en => ein, input => din_padded, output => min );
	-- input register (for xor at the last round of a block )
	min_reg : regn generic map ( N => mw, init => mwzeros ) port map ( clk => clk, rst => '0', en => srdp, input => min, output => min_out );
	-- input to r reg
	hm <= ( min xor hp_or_iv(b-1 downto b/2) ) & hp_or_iv(b/2-1 downto 0);	
	hp_or_iv <= iv when sf = '1' else hp;	
	
	-- group (rearrange them into correct order)		   
	g <= form_group( hm, b, crw );
	rin <= g when srdp = '1' else rd_out(UF-1);

	--R registers
	rreg_gen : regn generic map ( N => b, init => bzeros ) port map ( clk => clk, rst => '0', en => er, input => rin, output => rout );		
		
	-- output to round function	 
	dg <= degroup( rout, b, crw );
 	hp <= dg(b-1 downto b/2) & ( min_out xor dg(b/2-1 downto 0) );
	
	-- output 
	shfout_gen : piso generic map ( N => h, M => w ) port map (clk => clk, sel => lo, en => eout, input => hp(h-1 downto 0), output => dout );			
	
	UF1 : if UF=1 generate
		-- RC 
		crd_reg : regn generic map ( N => crw, init => cr8_iv ) port map ( clk => clk, rst => erf, en => er, input => crdp, output => crd_out(0) );
		crd_gen : entity work.jh_rd(struct) generic map ( bw => crw, cw => crkw ) port map ( input => crd_out(0), cr => crkwzeros, output => crdp);
		-- ROUND
		rd_gen 	: entity work.jh_rd(struct) generic map ( bw => b, cw => crw  ) port map ( input => rout, cr => crd_out(0), output => rd_out(0) );
	end generate;
		
	UF2 : if UF=2 generate
		-- RC 
		crd_reg : regn generic map ( N => crw, init => cr8_iv ) port map ( clk => clk, rst => erf, en => er, input => crdp, output => crd_out(0) );
		crd1_gen : entity work.jh_rd(struct) generic map ( bw => crw, cw => crkw ) port map ( input => crd_out(0), cr => crkwzeros, output => crd_out(1));
		crd2_gen : entity work.jh_rd(struct) generic map ( bw => crw, cw => crkw ) port map ( input => crd_out(1), cr => crkwzeros, output => crdp);
		-- ROUND
		rd1_gen 	: entity work.jh_rd(struct) generic map ( bw => b, cw => crw  ) port map ( input => rout, cr => crd_out(0), output => rd_out(0) );
		rd2_gen 	: entity work.jh_rd(struct) generic map ( bw => b, cw => crw  ) port map ( input => rd_out(0), cr => crd_out(1), output => rd_out(1) );
	end generate;
--	--debug
	-- rin_m <= blk2wordmatrix_inv( rin );
	-- rout_m <= blk2wordmatrix_inv( rout );
	-- rd_out_m <= blk2wordmatrix_inv( rd_out(ux-1) );
--	dg_m <= blk2wordmatrix_inv( dg );
--	hp_m <= blk2wordmatrix_inv( hp );
--	hm_m <= blk2wordmatrix_inv( hm );
--	crdo <= crd_out & zeros;
--	crd_out_m <= blk2wordmatrix_inv( crdo );
end struct;