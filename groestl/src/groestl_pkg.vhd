-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use work.sha3_pkg.all;

package groestl_pkg is
-- data capacity for different versions of Groestl
constant GROESTL_DATA_SIZE_BIG				:integer:=1024;
constant GROESTL_DATA_SIZE_SMALL			:integer:=512;

-- names of different architectures
constant GROESTL_ARCH_PQ_Fx8				:integer:=1;
constant GROESTL_ARCH_PQ_Fx4				:integer:=2;
constant GROESTL_ARCH_PQ_Fx2				:integer:=3;
constant GROESTL_ARCH_PQ_QPPL				:integer:=4;
constant GROESTL_ARCH_PQ_U2					:integer:=5;
constant GROESTL_ARCH_PQ_UX					:integer:=6;

constant GROESTL_ARCH_PARALLEL_VER1			:integer:=7;
constant GROESTL_ARCH_PARALLEL_VER2			:integer:=8;


-- initialivation vectors for different versions of Groestl
constant GROESTL_INIT_VALUE_224			:std_logic_vector(GROESTL_DATA_SIZE_SMALL-1 downto 0) := x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000E0";
constant GROESTL_INIT_VALUE_256			:std_logic_vector(GROESTL_DATA_SIZE_SMALL-1 downto 0) := x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100";
constant GROESTL_INIT_VALUE_384			:std_logic_vector(GROESTL_DATA_SIZE_BIG-1 downto 0) := x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000180";
constant GROESTL_INIT_VALUE_512			:std_logic_vector(GROESTL_DATA_SIZE_BIG-1 downto 0) := x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200";

constant w		: integer := 64;		-- message interface
-- number of clock cycles per architecture
constant pq_roundnr256 				: integer := 21;
constant pq_roundnr_final256 		: integer := 21;
constant pq_log2roundnr_final256	: integer := log2( pq_roundnr256);

constant pq_roundnr512 				: integer := 29;
constant pq_roundnr_final512 		: integer := 29;
constant pq_log2roundnr_final512	: integer := log2( pq_roundnr512);

-- parallel
constant pq_ux2_roundnr256 			: integer := 10;
constant pq_ux2_roundnr_final256 	: integer := 10;
constant pq_ux2_log2roundnr_final256: integer := log2( pq_ux2_roundnr256);

constant pq_ux2_roundnr512 			: integer := 17;
constant pq_ux2_roundnr_final512 	: integer := 17;
constant pq_ux2_log2roundnr_final512: integer := log2( pq_ux2_roundnr512);

-- parallel folded 	folding factor ff=2

constant pq_ux2_fx2_roundnr256 			: integer := 20;
constant pq_ux2_fx2_roundnr_final256 	: integer := 20;
constant pq_ux2_fx2_log2roundnr_final256: integer := log2( pq_ux2_fx2_roundnr256);

constant pq_ux2_fx2_roundnr512 			: integer := 28;
constant pq_ux2_fx2_roundnr_final512 	: integer := 28;
constant pq_ux2_fx2_log2roundnr_final512: integer := log2( pq_ux2_fx2_roundnr512);

-- parallel folded 	folding factor ff=4

constant pq_ux2_fx4_roundnr256 			: integer := 40;
constant pq_ux2_fx4_roundnr_final256 	: integer := 40;
constant pq_ux2_fx4_log2roundnr_final256: integer := log2( pq_ux2_fx4_roundnr256);

constant pq_ux2_fx4_roundnr512 			: integer := 56;
constant pq_ux2_fx4_roundnr_final512 	: integer := 56;
constant pq_ux2_fx4_log2roundnr_final512: integer := log2( pq_ux2_fx4_roundnr512);

-- parallel folded 	folding factor ff=8

constant pq_ux2_fx8_roundnr256 			: integer := 80;
constant pq_ux2_fx8_roundnr_final256 	: integer := 80;
constant pq_ux2_fx8_log2roundnr_final256: integer := log2( pq_ux2_fx8_roundnr256);

constant pq_ux2_fx8_roundnr512 			: integer := 112;
constant pq_ux2_fx8_roundnr_final512 	: integer := 112;
constant pq_ux2_fx8_log2roundnr_final512: integer := log2( pq_ux2_fx8_roundnr512);

-- quasi-pipelined folding factor ff=2
constant pq_fx2_roundnr256 			: integer := 42;
constant pq_fx2_roundnr_final256 	: integer := 42;
constant pq_fx2_log2roundnr_final256: integer := log2( pq_fx2_roundnr256);

constant pq_fx2_roundnr512 			: integer := 58;
constant pq_fx2_roundnr_final512 	: integer := 58;
constant pq_fx2_log2roundnr_final512: integer := log2( pq_fx2_roundnr512);

-- quasi-pipelined folding factor ff=4
constant pq_fx4_roundnr256 			: integer := 84;
constant pq_fx4_roundnr_final256 	: integer := 84;
constant pq_fx4_log2roundnr_final256: integer := log2( pq_fx4_roundnr256);

constant pq_fx4_roundnr512 			: integer := 116;
constant pq_fx4_roundnr_final512 	: integer := 116;
constant pq_fx4_log2roundnr_final512: integer := log2( pq_fx4_roundnr512);

-- quasi-pipelined folding factor ff=8
constant pq_fx8_roundnr256 			: integer := 168;
constant pq_fx8_roundnr_final256 	: integer := 168;
constant pq_fx8_log2roundnr_final256: integer := log2( pq_fx8_roundnr256);

constant pq_fx8_roundnr512 			: integer := 232;
constant pq_fx8_roundnr_final512 	: integer := 232;
constant pq_fx8_log2roundnr_final512: integer := log2( pq_fx8_roundnr512);


constant pq_ux4_roundnr256 			: integer := 7;
constant pq_ux4_roundnr_final256 	: integer := 7;
constant pq_ux4_log2roundnr_final256: integer := log2( pq_ux4_roundnr256);

constant pq_ux4_roundnr512 			: integer := 9;
constant pq_ux4_roundnr_final512 	: integer := 9;
constant pq_ux4_log2roundnr_final512: integer := log2( pq_ux4_roundnr512);

constant pq_ux10_roundnr256 			: integer := 4;
constant pq_ux10_roundnr_final256 		: integer := 4;
constant pq_ux10_log2roundnr_final256	: integer := log2( pq_ux10_roundnr256);

constant pq_ux14_roundnr512 		: integer := 4;
constant pq_ux14_roundnr_final512 	: integer := 4;
constant pq_ux14_log2roundnr_final512	: integer := log2( pq_ux14_roundnr512);

--constant b		: integer := GROESTL_DATA_SIZE_SMALL;
--constant bseg			: integer := b/w;
--constant bzeros			: std_logic_vector(b-1 downto 0) := (others => '0');
constant wzeros			: std_logic_vector(w-1 downto 0) := (others => '0');

-- constants for different architectures supporting embedded resources
constant GROESTL_SBOX_ROUND		:integer:=1;
constant GROESTL_TBOX_ROUND		:integer:=2;

constant CTR_SHORT				: integer := 16;
constant CTR_FULL				: integer := 64;
constant CTR_SIZE				: integer := CTR_FULL;

end groestl_pkg;

package body groestl_pkg is
end package body groestl_pkg;