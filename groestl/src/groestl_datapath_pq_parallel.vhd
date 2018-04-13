 -- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.sha3_pkg.all;
use work.groestl_pkg.all;

-- Groestl datapath for quasi-pipelined architecture
-- possible generics values: hs = {GROESTL_DATA_SIZE_SMALL, GROESTL_DATA_SIZE_BIG}
-- rom_style = {DISTRIBUTED, COMBINATIONAL}
-- all combinations are allowed

entity groestl_datapath_pq_parallel is
generic (   n	:integer := GROESTL_DATA_SIZE_SMALL;
            hs : integer := HASH_SIZE_256;      
            rom_style : integer := DISTRIBUTED
         );
port(
	clk					: in std_logic;
	rst					: in std_logic;

	-- pad
    en_lb, clr_lb : in std_logic; -- decrement last block word count ... rem1_reg
    comp_rem_e0, comp_lb_e0, comp_extra_block : out std_logic;
    spos : in std_logic_vector(1 downto 0);
	sel_pad : in std_logic;
	rst_ctr : in std_logic;
	-- input
	ein					: in std_logic;
	en_len				: in std_logic;
	en_ctr				: in std_logic;
	en_c 				: in std_logic;

	-- processing
	init1				: in std_logic;
	init2				: in std_logic;
	init3				: in std_logic;
	finalization		: in std_logic;
	wr_state			: in std_logic;
	wr_result			: in std_logic;
	load_ctr			: in std_logic;
	wr_ctr				: in std_logic;

	-- output
	sel_out				: in std_logic;
	eout				: in std_logic;

	final_segment		: out std_logic;
	c 					: out std_logic_vector(31 downto log2( n ));
	din 				: in std_logic_vector(w-1 downto 0);
    dout 				: out std_logic_vector(w-1 downto 0));
end groestl_datapath_pq_parallel;

architecture basic of groestl_datapath_pq_parallel is
	constant log2mw : integer := log2( n );
	constant log2mwzeroes : std_logic_vector(log2mw-1 downto 0) := (others => '0');
	constant zero : std_logic_vector(n-1 downto 0):= (others=>'0');
    signal  rin, from_final, to_left_round, to_right_round, from_left_register, from_right_register, to_final : std_logic_vector(n-1 downto 0);
    signal  to_left_register, to_right_register, to_left_reg, to_right_reg, intermediate_left, two_xor, three_xor, to_init : std_logic_vector(n-1 downto 0);
	signal  ctr : std_logic_vector(3 downto 0);
	signal  round : std_logic_vector(7 downto 0);

	constant additional_bit : integer := n/512-1;
	constant zeros : std_logic_vector(63 downto 0) := (others => '0');
	signal remaining_bits : std_logic_vector(8+additional_bit downto 0);

	signal din_pad, din_select : std_logic_vector(63 downto 0);
	signal block_count : std_logic_vector(63 downto 0);
	signal sel_pad_type_lookup, sel_din_lookup : std_logic_vector( 7 downto 0 );
	signal sel_din, sel_pad_location : std_logic_vector(7 downto 0);
begin
	-- padding unit
	rem1_gen : decountern
		generic map ( N => 3 + additional_bit, sub => 1 )
		port map    ( clk => clk, rst => clr_lb, load => en_len, en => en_lb,
                      input => din(8 + additional_bit downto 6), output => remaining_bits(8 + additional_bit downto 6));
	rem2_reg : regn generic map ( N => 6, init => "000000" )
		port map ( clk => clk, rst => clr_lb, en => en_len, input => din(5 downto 0), output => remaining_bits(5 downto 0));

	comp_rem_e0 <= '1' when remaining_bits = 0 else '0';
	comp_lb_e0 <= '1' when remaining_bits(8+additional_bit downto 6) = zeros(2+additional_bit downto 0) else '0';
	comp_extra_block <= '1' when remaining_bits > n-65 else '0';

	sel_pad_type_lookup <= lookup_sel_lvl2_64bit_pad(conv_integer(remaining_bits(5 downto 3)));
	sel_din_lookup <= lookup_sel_lvl1_64bit_pad(conv_integer(remaining_bits(5 downto 3)));

	sel_din <= (others => '1') when spos(1) = '1' else sel_din_lookup;
	sel_pad_location <= (others => '0') when spos(0) = '0' else sel_pad_type_lookup;

	block_counter_gen : entity work.pipelined_counter(struct)
		generic map ( osize => 64, adder_size => 16 )
		port map ( clk => clk, rst => rst_ctr, en => en_ctr, o => block_count );

	byte_pad_gen : entity work.byte_pad(struct)
		generic map ( w => 64 )
		port map ( din => din, dout => din_pad, sel_pad_location => sel_pad_location, sel_din =>  sel_din);

	din_select <= block_count when sel_pad = '1' else din_pad;
	
	-- Final segment	
	final_segment <= din(63);	

	--Pad Unit
	decounter_gen : decountern 
        generic map ( N => 32-log2mw, sub => 1 ) 
        port map    ( clk => clk, rst => '0', load => en_len, en => en_c, 
                      input => din(31 downto log2mw), output => c(31 downto log2mw) );


	-- serial input parallel output
	shfin_gen : sipo
	generic map ( N => n, M =>w)
	port map (clk => clk, en => ein, input => din_select, output => rin );

	intermediate_left <= from_final when init2='1' else from_left_register;

	--to_final
	to_left_round <= 	(rin xor from_final) when init1='1' else intermediate_left;
	to_right_round <= 	rin  when init1='1' else from_right_register;

	-- round counter
	rd_num : countern
	generic map (N =>4, step=>1, style =>COUNTER_STYLE_1)
	port map (clk=>clk, rst=>rst, load=>load_ctr, en=>wr_ctr, input=> zero(3 downto 0) ,  output=>ctr);
	round <= zero(3 downto 0) & ctr;	
	
	-- parallel round
	left_round : entity work.groestl_pq_parallel(round3_combinational)
		generic map (n=>n, rom_style => rom_style, p_mode => 1)
		port map (round=>round, input=>to_left_round, output=>to_left_register);

	right_round : entity work.groestl_pq_parallel(round3_combinational)
		generic map (n=>n, rom_style => rom_style, p_mode => 0)
		port map (round=>round, input=>to_right_round, output=>to_right_register);

	-- storage register for intermediate values
	lstate_reg : regn
	generic map(N=>n, init=>zero(n-1 downto 0))
	port map (clk => clk, rst => rst, en => wr_state, input => to_left_register, output => from_left_register );

	rstate_reg : regn
	generic map(N=>n, init=>zero(n-1 downto 0))
	port map (clk => clk, rst => rst, en => wr_state, input => to_right_register, output => from_right_register );

	two_xor <= from_final xor to_left_register;
	three_xor <= two_xor xor to_right_register;

	to_init <= two_xor when finalization='1' else three_xor;
															
	-- initialization vectors for different versions of Groestl
	iv224: if hs=HASH_SIZE_224 generate
		to_final <= GROESTL_INIT_VALUE_224 when init3='1' else to_init;
	end generate;

	iv256: if hs=HASH_SIZE_256 generate
		to_final <= GROESTL_INIT_VALUE_256 when init3='1' else to_init;
	end generate;

	iv384: if hs=HASH_SIZE_384 generate
		to_final <= GROESTL_INIT_VALUE_384 when init3='1' else to_init;
	end generate;

	iv512: if hs=HASH_SIZE_512 generate
		to_final <= GROESTL_INIT_VALUE_512 when init3='1' else to_init;
	end generate;

	-- final message digest storage register
	final_reg : regn
	generic map(N=>n, init=>zero(n-1 downto 0))
	port map (clk => clk, rst => rst, en => wr_result, input => to_final, output => from_final );

	-- parallel input serial output
	shfout_gen : piso
	generic map ( N => hs , M => w )
	port map (clk => clk, sel => sel_out, en => eout, input => from_final(hs-1 downto 0), output => dout );


end basic;

