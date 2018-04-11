-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.sha3_skein_package.ALL;
use work.sha3_pkg.all;

entity skein_datapath is
	generic ( 	
		version : integer := SHA3_ROUND3;
		adder_type : integer := SCCA_BASED;
		w : integer := 64;
		h : integer := HASH_SIZE_256;				
		round_unrolled : integer := 4 );
	port (
		-- external
		clk : in std_logic;
		rst : in std_logic;
		din  : in std_logic_vector(w-1 downto 0);	
		dout : out std_logic_vector(w-1 downto 0);	
		--fsm 1		
		clr_rem, ein : in std_logic;
		ec, lc : in std_logic;	  	
		zc0, zcRemNon0, zcRem1, padded : out std_logic;
		dth, eth : in std_logic;	
		-- pad
		en_lb, clr_lb : in std_logic; -- decrement last block word count ... rem1_reg
        comp_rem_e0, comp_lb_e0 : out std_logic;
        spos : in std_logic;
		-- Tweak			  		  
			tw_bit_pad : in std_logic;
			tw_final, tw_first : in std_logic;
			tw_type : in std_logic_vector(5 downto 0);
		--fsm 2			  		
		er, etweak : in std_logic;
		sf : in std_logic;		-- 1 for first block of a message
		lo : in std_logic;
		
		sfinal : in std_logic; 	 -- 0 for msg, 1 for output
		slast 	: in std_logic;  -- 1 for last block and output , 0 else
		snb		: in std_logic;
		rsel 	: in std_logic_vector(2 downto 0); -- rotation select (for 1 round unroll)
		
		--fsm 3
		eout : in std_logic		
	);				  
end skein_datapath;

architecture struct of skein_datapath is   

	function get_key_size (ux : integer ) return integer is
	begin
		if ( ux = 8 ) then
			return ( 2 );
		else
			return ( 1 ) ;
		end if;
	end get_key_size;
	
	------ Constants		
	constant nw : integer := 8; -- fixed
	constant b : integer := 512; -- fixed	   
	constant bzeros 	: std_logic_vector(b-1 downto 0) := (others => '0');
	constant mw			: integer := b;		-- message width	
	constant log2mw : integer := log2(mw);						
	constant log2mwzeros : std_logic_vector(log2mw-1 downto 0) := (others => '0');
	constant mwzeros	: std_logic_vector(mw-1 downto 0) := (others => '0');  
	constant key_size	: integer := get_key_size(round_unrolled);
	constant perm : permute_type (0 to nw-1) := get_perm( b );
	constant rot : rot_type (0 to nw/2-1,0 to 7) := get_rot( b );  
	constant iv : std_logic_vector(b-1 downto 0) := get_iv( h, version );																			  
	constant sixteenzeros : std_logic_vector(15 downto 0) := (others => '0');	 
	constant seventyone0 : std_logic_vector(70 downto 0) := (others =>'0');
	constant remzeros : std_logic_vector(log2mw-4 downto 0) := (others => '0');
	constant remones : std_logic_vector(log2mw-4 downto 0) := (others => '1');		
	constant msg_cntr_size : integer := 16;
	----------	

	-- BYTE COUNTER 
	signal remainder, rem_data : std_logic_vector(log2mw-4 downto 0);
	signal block_count : std_logic_vector(15 downto 0);
	signal cpad : std_logic;
	-- TWEAK
	signal tweak : std_logic_vector(127 downto 0);				  
	constant tw_tree_level : std_logic_vector(6 downto 0) := (others =>'0');
	constant tw_reserved : std_logic_vector(15 downto 0) := (others =>'0');	
	constant tw_pos_zeros : std_logic_vector(73 downto 0) := (others => '0');
	signal tw_position : std_logic_vector(21 downto 0);	   

	-- PADDING UNIT
	signal remaining_bits : std_logic_vector(8 downto 0);
	signal din_padded : std_logic_vector(w-1 downto 0);
	signal sel_pad_type_lookup, sel_din_lookup : std_logic_vector( 7 downto 0 ); 	
	signal sel_din, sel_pad_location : std_logic_vector(7 downto 0);
	-- BLOCK COUNTERS
	signal c : std_logic_vector(msg_cntr_size-1 downto 0);
	
	-- ROUND SIGNALS			 
	signal min,min_endian1,min_endian2, msg : std_logic_vector(mw-1 downto 0);
	signal r, rmux, rp : std_logic_vector(b-1 downto 0);
	signal keyout  : round_array(key_size-1 downto 0, nw-1 downto 0);	
	signal threefish, cv,  keyin : std_logic_vector(b-1 downto 0);	  
	signal switch_out, switch1, switch2 : std_logic_vector(h-1 downto 0);
	signal keyinj : round_array(key_size-1 downto 0, nw-1 downto 0);	
	signal round : round_array(0 to round_unrolled, nw-1 downto 0);	
	signal roundout : round_array(0 to round_unrolled-1, nw-1 downto 0);	  
	
	-- 1x
	signal keysel : round_array(key_size-1 downto 0, nw-1 downto 0);
	-- 4x
	signal sshalf : std_logic;
	
	
	
begin														
	-- block decounter																									   	
	decounter_gen : decountern 
		generic map ( N => msg_cntr_size, sub => 1 ) 
		port map ( clk => clk, rst => '0', load => lc, en => ec, input => din(log2mw+msg_cntr_size-1 downto log2mw), output => c);	
			
	-- padding unit
	rem1_gen : decountern 
		generic map ( N => 3, sub => 1 ) 
		port map ( clk => clk, rst => clr_lb, load => lc, en => en_lb, input => din(8 downto 6), output => remaining_bits(8 downto 6));	
	rem2_reg : regn generic map ( N => 6, init => "000000" ) 
		port map ( clk => clk, rst => clr_lb, en => lc, input => din(5 downto 0), output => remaining_bits(5 downto 0));	
	
	
	sel_din_lookup <= lookup_sel_lvl1_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_din <= (others => '1') when spos = '1' else sel_din_lookup;	

	byte_pad_gen : entity work.skein_byte_pad(struct)
		generic map ( w => 64 ) 
		port map ( din => din, dout => din_padded, sel_din =>  sel_din);	

	comp_rem_e0 <= '1' when remaining_bits = 0 else '0';
	comp_lb_e0 <= '1' when remaining_bits(8 downto 6) = "000" else '0';
		
    -- tweak
	remreg_gen : regn 
		generic map ( N => log2mw-3, init => remzeros ) 
		port map ( clk => clk, rst => clr_rem, en => lc, input => din(log2mw-1 downto 3), output => remainder);
	cpad_gen : process ( clk )
	begin
		if rising_edge( clk ) then
			if clr_rem = '1' then
				cpad <= '0';
			elsif lc = '1' then
				cpad <= din(2) or din(1) or din(0);
			end if;
		end if;
	end process;		  
	
	padded <= cpad;
	zc0 <= '1' when c = conv_std_logic_vector(0,16) else '0';
	zcRemNon0 <= '0' when remainder = remzeros else '1';
	zcRem1 <= '1' when remainder = remones else '0';		
	
	-- t gens																			  
	block_counter_gen : countern
		generic map ( N => 16 ) 
		port map ( clk => clk, rst => rst, load => dth, en => eth, input => sixteenzeros, output => block_count);
		rem_data <= remainder + cpad when slast = '1' else (others =>'0');
		tw_position <= conv_std_logic_vector(8,16+log2mw-3) when sfinal = '1' else block_count & rem_data  ;
		-- tweak				
		-- tw_type <= TW_OUT_CONS when sfinal = '1' else TW_MSG_CONS;			
		-- tw_bit_pad <= cpad and slast and not sfinal;				 
		-- tw_final  <= (slast or sfinal)
		-- tw_first  <= (sf or sfinal)
		tweak <= tw_final & tw_first  & tw_type & tw_bit_pad & tw_tree_level & tw_reserved & tw_pos_zeros & tw_position;
	
	-- input																										 
	min_endian1 <= switch_endian_byte(min,b,64);
	min_endian2 <= switch_endian_word(min_endian1,b,64);
	shfin_gen : sipo generic map ( N => mw,M => w) port map (clk => clk, en => ein, input => din_padded, output => min );
	msg_reg : regn generic map ( N => mw, init => mwzeros ) port map ( clk => clk, rst => sfinal, en => snb, input => min_endian2, output => msg );
	
	rmux <= min_endian2 when snb = '1' else rp;
	r_reg : regn generic map ( N => b, init => bzeros ) port map ( clk => clk, rst => sfinal, en => er, input => rmux, output => r );
	
	-----------------------
	--------- ROUND -------
	inout_gen : for i in nw-1 downto 0 generate
		round(0,i) <= r(iw*(i+1)-1 downto iw*i);
		rp(iw*(i+1)-1 downto iw*i) <= round(round_unrolled,i);
	end generate;		
	
	
	gen_1x : if round_unrolled = 1 generate
		keyinj_gen : for j in nw-1 downto 0 generate 
			keysel(0,j) <= keyout(0,j) when etweak = '1' else (others => '0');
			add_call : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => keysel(0,j), b => round(0,j) , s => keyinj(0,j));			
		end generate;			
		mix_gen_gen : for j in 0 to nw/2-1 generate
			mix_gen : entity work.skein_mix_1r(struct) generic map ( adder_type => adder_type, col => j ) port map ( rsel => rsel, a => keyinj(0,2*j), b => keyinj(0,2*j+1), c => roundout(0,2*j), d => roundout(0,2*j+1) );
		end generate;
	end generate;
		--------------------
		--------- 4x -------			
	gen_4x : if round_unrolled = 4 generate
		-- cntrl signal	
		process ( clk )	   
		begin
			if rising_edge( clk ) then
				if ( snb = '1' ) then
					sshalf <= '0';
				elsif ( er = '1' ) then
					sshalf <= not sshalf;
				end if;
			end if;
		end process;	
		-- core
		row_gen : for i in 0 to round_unrolled-1 generate
			key_inj : if ( i mod 4 = 0 ) generate																								
				keyinj_gen : for j in nw-1 downto 0 generate 
					add_call : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => keyout(0,j), b => round(i,j) , s => keyinj(i/4,j));
					--keyinj(i/4,j) <= round(i,j) + keyout(0,j);
				end generate;			
				mix_gen_gen : for j in 0 to nw/2-1 generate
					mix_gen : entity work.skein_mix_4r(struct) generic map ( adder_type => adder_type, rotate_0 => rot(j,i), rotate_1 => rot(j,i+4) ) port map ( sel => sshalf, a => keyinj(i/4,2*j), b => keyinj(i/4,2*j+1), c => roundout(i,2*j), d => roundout(i,2*j+1) );
				end generate;
			end generate;
			nokey_inj : if (i mod 4 /= 0 ) generate	
				mix_gen_gen : for j in 0 to nw/2-1 generate
					mix_gen_r : entity work.skein_mix_4r(struct) generic map (adder_type => adder_type,  rotate_0 => rot(j,i), rotate_1 => rot(j,i+4) ) port map ( sel => sshalf, a => round(i,2*j), b => round(i,2*j+1), c => roundout(i,2*j), d => roundout(i,2*j+1) );
				end generate;
			end generate;
		end generate;	
	end generate;		 
		--------------------
		--------- 8x -------
	gen_8x : if round_unrolled = 8 generate
		row_gen : for i in 0 to round_unrolled-1 generate
			key_inj : if ( i mod 4 = 0 ) generate																								
				keyinj_gen : for j in nw-1 downto 0 generate 
					add_call : adder generic map ( adder_type => adder_type, n => 64 ) port map ( a => keyout(i/4,j), b => round(i,j) , s => keyinj(i/4,j));
					--keyinj(i/4,j) <= round(i,j) + keyout(i/4,j);
				end generate;			
				mix_gen_gen : for j in 0 to nw/2-1 generate
					mix_gen_l : entity work.skein_mix_8r(struct) generic map ( adder_type => adder_type, rotate => rot(j,i) ) port map ( a => keyinj(i/4,2*j), b => keyinj(i/4,2*j+1), c => roundout(i,2*j), d => roundout(i,2*j+1) );	
				end generate;
			end generate;
			nokey_inj : if (i mod 4 /= 0 ) generate		
				mix_gen_gen : for j in 0 to nw/2-1 generate
					mix_gen_l : entity work.skein_mix_8r(struct) generic map ( adder_type => adder_type, rotate => rot(j,i) ) port map ( a => round(i,2*j), b => round(i,2*j+1), c => roundout(i,2*j), d => roundout(i,2*j+1) );	
				end generate;
			end generate;	  			
		end generate;	 	  		
	end generate;			  
	
	perm1: for i in 1 to round_unrolled generate 
		perm2 : for j in 0 to nw-1 generate
			round(i,j) <= roundout(i-1,perm(j));
		end generate;
	end generate;
	--------- ROUND -------
	-----------------------			   
	
	threefish_out_gen : for i in nw-1 downto 0 generate
		threefish(64*(i+1)-1 downto 64*i) <= keyinj(0,i);
	end generate;
	cv <= threefish xor msg;
	
	keyin <= iv when sf = '1' else cv;
	keygen_gen : entity work.skein_keygen(struct) 
		generic map (version => version, adder_type => adder_type, b => b, nw => nw, key_size => key_size) 
		port map ( clk => clk, load => snb, en => etweak, keyin => keyin, tweak => tweak, keyout => keyout );
	
	switch_out <= cv(h-1 downto 0);
	switch1 <= switch_endian_word(switch_out, h, iw); 
	switch2 <= switch_endian_byte(switch1,h,iw);
		
	--output	
	shfout_gen : piso generic map ( N => h, M => w ) port map (clk => clk, sel => lo, en => eout, input => switch2, output => dout );		
end struct;