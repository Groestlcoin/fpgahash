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

package sha3_jh_package is		   

	-- RC GENERATION SCHEMES
	constant ON_THE_FLY : integer := 0;
	constant MEMORY : integer := 1;
	-- ===================
	-- Depending parameter values, use the following :
	-- ===================
	-- for r/b-h = 16/32-256 
	-- roundnr = r = 16
	-- mw = b*8 = 32*8 = 256
	-- h = h = 256
	-- ===================		  
	constant d		: integer := 8;
	constant b		: integer := 2**(d+2);
	constant mw		: integer := 2**(d+1);		-- message width
	
	constant crw	: integer := 2**d;			-- cr width
	constant crkw	: integer := 2**(d-2);		-- cr key width
	
	constant w		: integer := 64;		-- message interface	

	
	
	
	constant bseg			: integer := b/w;  
		
	constant mwseg			: integer := mw/w;	
	constant log2mw 		: integer := log2( mw );
	constant log2mwseg 		: integer := log2( mwseg );
	
 	constant log2mwsegzeros	: std_logic_vector(log2mwseg-1 downto 0) := (others => '0');
	constant bzeros			: std_logic_vector(b-1 downto 0) := (others => '0');
	constant wzeros			: std_logic_vector(w-1 downto 0) := (others => '0');
	constant mwzeros		: std_logic_vector(mw-1 downto 0) := (others => '0');
	constant crkwzeros 		: std_logic_vector(crkw-1 downto 0) := (others => '0');
	
	
	type sbox_type is array (0 to 1, 0 to 15) of std_logic_vector(3 downto 0);
	constant sbox_rom : sbox_type := ((	"1001", "0000", "0100", "1011", "1101", "1100", "0011", "1111",
										"0001", "1010", "0010", "0110", "0111", "0101", "1000", "1110"),
									  (	"0011", "1100", "0110", "1101", "0101", "0111", "0001", "1001",
										"1111", "0010", "0000", "0100", "1011", "1010", "1110", "1000"));
										
	type std_logic_matrix is array (31 downto 0) of std_logic_vector(31 downto 0) ;
	function blk2wordmatrix_inv	(signal x : in std_logic_vector(b-1 downto 0) ) return std_logic_matrix;
	function form_group  (hm : in std_logic_vector; b : integer; cw : integer ) return std_logic_vector;
	function degroup  (rd : in std_logic_vector; b : integer; cw : integer ) return std_logic_vector;
	function get_iv ( h : integer ) return std_logic_vector;
	function permute ( ii : std_logic_vector; bw : integer; cw : integer ) return std_logic_vector;
	-- iv		 
   	constant cr8_iv	: std_logic_vector(crw-1 downto 0) := x"6A09E667F3BCC908B2FB1366EA957D3E3ADEC17512775099DA2F590B0667322A";
	constant iv512 : std_logic_vector(b-1 downto 0) := x"50AB6058C60942CC4CE7A54CBDB9DC1BAF2E7AFBD1A15E24E5F44EABC4D5C0A14CF243660C562073999381EA9A8B3D18CF65D9FCA940B6C79E831273BEFE3B660F9A2F7E0A32D8E017D491558E0B134005B5E4DEC44E5F3F8CBC5AEE98FD1D3214081C25E46CE6C41B4B95BCE1BD43DB7F229EC243B680140A33B909333C0303";
	constant iv256 : std_logic_vector(b-1 downto 0)   := x"C968B8E2C53A596E427E45EF1D7AE6E56145B7D906711F7A2FC7617806A922017B2991C1B91929E2C42B4CE18CC5A2D66220BECA901B5DDFD3B205638EA7AC5F143E8CBA6D313104B0E70054905272714CCE321E075DE5101BA800ECE20251789F5772795FD104A5F0B8B63425F5B2381670FA3E5F907F17E28FC064E769AC90";
	constant iv256r3 : std_logic_vector(b-1 downto 0) := x"EB98A3412C20D3EB92CDBE7B9CB245C11C93519160D4C7FA260082D67E508A03A4239E267726B945E0FB1A48D41A9477CDB5AB26026B177A56F024420FFF2FA871A396897F2E4D751D144908F77DE262277695F776248F9487D5B6574780296C5C5E272DAC8E0D6C518450C657057A0F7BE4D367702412EA89E3AB13D31CD769";
	constant iv512r3 : std_logic_vector(b-1 downto 0) := x"6FD14B963E00AA17636A2E057A15D5438A225E8D0C97EF0BE9341259F2B3C361891DA0C1536F801E2AA9056BEA2B6D80588ECCDB2075BAA6A90F3A76BAF83BF70169E60541E34A6946B58A8E2E6FE65A1047A7D0C1843C243B6E71B12D5AC199CF57F6EC9DB1F856A706887C5716B156E3C2FCDFE68517FB545A4678CC8CDD4B";
	
	

	type rc_type is array( 0 to 43 ) of std_logic_vector(255 downto 0);	
	constant rc_cons : rc_type := 	
		(x"6a09e667f3bcc908b2fb1366ea957d3e3adec17512775099da2f590b0667322a",
		x"bb896bf05955abcd5281828d66e7d99ac4203494f89bf12817deb43288712231",
		x"1836e76b12d79c55118a1139d2417df52a2021225ff6350063d88e5f1f91631c",
		x"263085a7000fa9c3317c6ca8ab65f7a7713cf4201060ce886af855a90d6a4eed",
		x"1cebafd51a156aeb62a11fb3be2e14f60b7e48de85814270fd62e97614d7b441",
		x"e5564cb574f7e09c75e2e244929e9549279ab224a28e445d57185e7d7a09fdc1",
		x"5820f0f0d764cff3a5552a5e41a82b9eff6ee0aa615773bb07e8603424c3cf8a",
		x"b126fb741733c5bfcef6f43a62e8e5706a26656028aa897ec1ea4616ce8fd510",
		x"dbf0de32bca77254bb4f562581a3bc991cf94f225652c27f14eae958ae6aa616",
		x"e6113be617f45f3de53cff03919a94c32c927b093ac8f23b47f7189aadb9bc67",
		x"80d0d26052ca45d593ab5fb3102506390083afb5ffe107dacfcba7dbe601a12b",
		x"43af1c76126714dfa950c368787c81ae3beecf956c85c962086ae16e40ebb0b4",
		x"9aee8994d2d74a5cdb7b1ef294eed5c1520724dd8ed58c92d3f0e174b0c32045",
		x"0b2aa58ceb3bdb9e1eef66b376e0c565d5d8fe7bacb8da866f859ac521f3d571",
		x"7a1523ef3d970a3a9b0b4d610e02749d37b8d57c1885fe4206a7f338e8356866",
		x"2c2db8f7876685f2cd9a2e0ddb64c9d5bf13905371fc39e0fa86e1477234a297",
		x"9df085eb2544ebf62b50686a71e6e828dfed9dbe0b106c9452ceddff3d138990",
		x"e6e5c42cb2d460c9d6e4791a1681bb2e222e54558eb78d5244e217d1bfcf5058",
		x"8f1f57e44e126210f00763ff57da208a5093b8ff7947534a4c260a17642f72b2",
		x"ae4ef4792ea148608cf116cb2bff66e8fc74811266cd641112cd17801ed38b59",
		x"91a744efbf68b192d0549b608bdb3191fc12a0e83543cec5f882250b244f78e4",
		x"4b5d27d3368f9c17d4b2a2b216c7e74e7714d2cc03e1e44588cd9936de74357c",
		x"0ea17cafb8286131bda9e3757b3610aa3f77a6d0575053fc926eea7e237df289",
		x"848af9f57eb1a616e2c342c8cea528b8a95a5d16d9d87be9bb3784d0c351c32b",
		x"c0435cc3654fb85dd9335ba91ac3dbde1f85d567d7ad16f9de6e009bca3f95b5",
		x"927547fe5e5e45e2fe99f1651ea1cbf097dc3a3d40ddd21cee260543c288ec6b",
		x"c117a3770d3a34469d50dfa7db020300d306a365374fa828c8b780ee1b9d7a34",
		x"8ff2178ae2dbe5e872fac789a34bc228debf54a882743caad14f3a550fdbe68f",
		x"abd06c52ed58ff091205d0f627574c8cbc1fe7cf79210f5a2286f6e23a27efa0",
		x"631f4acb8d3ca4253e301849f157571d3211b6c1045347befb7c77df3c6ca7bd",
		x"ae88f2342c23344590be2014fab4f179fd4bf7c90db14fa4018fcce689d2127b",
		x"93b89385546d71379fe41c39bc602e8b7c8b2f78ee914d1f0af0d437a189a8a4",
		x"1d1e036abeef3f44848cd76ef6baa889fcec56cd7967eb909a464bfc23c72435",
		x"a8e4ede4c5fe5e88d4fb192e0a0821e935ba145bbfc59c2508282755a5df53a5",
		x"8e4e37a3b970f079ae9d22a499a714c875760273f74a9398995d32c05027d810",
		x"61cfa42792f93b9fde36eb163e978709fafa7616ec3c7dad0135806c3d91a21b",
		x"f037c5d91623288b7d0302c1b941b72676a943b372659dcd7d6ef408a11b40c0",
		x"2a306354ca3ea90b0e97eaebcea0a6d7c6522399e885c613de824922c892c490",
		x"3ca6cdd788a5bdc5ef2dceeb16bca31e0a0d2c7e9921b6f71d33e25dd2f3cf53",
		x"f72578721db56bf8f49538b0ae6ea470c2fb1339dd26333f135f7def45376ec0",
		x"e449a03eab359e34095f8b4b55cd7ac7c0ec6510f2c4cc79fa6b1fee6b18c59e",
		x"73bd6978c59f2b219449b36770fb313fbe2da28f6b04275f071a1b193dde2072",  
		x"6a09e667f3bcc908b2fb1366ea957d3e3adec17512775099da2f590b0667322a",
		x"6a09e667f3bcc908b2fb1366ea957d3e3adec17512775099da2f590b0667322a");
		
	type rc_half_type is array(0 to 1, 0 to 21 ) of std_logic_vector(255 downto 0);
		
	constant rc_cons_half : rc_half_type := 	
		((x"6a09e667f3bcc908b2fb1366ea957d3e3adec17512775099da2f590b0667322a",	
		x"1836e76b12d79c55118a1139d2417df52a2021225ff6350063d88e5f1f91631c",	
		x"1cebafd51a156aeb62a11fb3be2e14f60b7e48de85814270fd62e97614d7b441",		
		x"5820f0f0d764cff3a5552a5e41a82b9eff6ee0aa615773bb07e8603424c3cf8a",		
		x"dbf0de32bca77254bb4f562581a3bc991cf94f225652c27f14eae958ae6aa616",	
		x"80d0d26052ca45d593ab5fb3102506390083afb5ffe107dacfcba7dbe601a12b",		
		x"9aee8994d2d74a5cdb7b1ef294eed5c1520724dd8ed58c92d3f0e174b0c32045",		
		x"7a1523ef3d970a3a9b0b4d610e02749d37b8d57c1885fe4206a7f338e8356866",		
		x"9df085eb2544ebf62b50686a71e6e828dfed9dbe0b106c9452ceddff3d138990",		
		x"8f1f57e44e126210f00763ff57da208a5093b8ff7947534a4c260a17642f72b2",		
		x"91a744efbf68b192d0549b608bdb3191fc12a0e83543cec5f882250b244f78e4",		
		x"0ea17cafb8286131bda9e3757b3610aa3f77a6d0575053fc926eea7e237df289",		
		x"c0435cc3654fb85dd9335ba91ac3dbde1f85d567d7ad16f9de6e009bca3f95b5",		
		x"c117a3770d3a34469d50dfa7db020300d306a365374fa828c8b780ee1b9d7a34",		
		x"abd06c52ed58ff091205d0f627574c8cbc1fe7cf79210f5a2286f6e23a27efa0",		
		x"ae88f2342c23344590be2014fab4f179fd4bf7c90db14fa4018fcce689d2127b",		
		x"1d1e036abeef3f44848cd76ef6baa889fcec56cd7967eb909a464bfc23c72435",		
		x"8e4e37a3b970f079ae9d22a499a714c875760273f74a9398995d32c05027d810",		
		x"f037c5d91623288b7d0302c1b941b72676a943b372659dcd7d6ef408a11b40c0",		
		x"3ca6cdd788a5bdc5ef2dceeb16bca31e0a0d2c7e9921b6f71d33e25dd2f3cf53",		
		x"e449a03eab359e34095f8b4b55cd7ac7c0ec6510f2c4cc79fa6b1fee6b18c59e",
		x"0000000000000000000000000000000000000000000000000000000000000000"
		),(		
		x"bb896bf05955abcd5281828d66e7d99ac4203494f89bf12817deb43288712231",
		x"263085a7000fa9c3317c6ca8ab65f7a7713cf4201060ce886af855a90d6a4eed",
		x"e5564cb574f7e09c75e2e244929e9549279ab224a28e445d57185e7d7a09fdc1",
		x"b126fb741733c5bfcef6f43a62e8e5706a26656028aa897ec1ea4616ce8fd510",
		x"e6113be617f45f3de53cff03919a94c32c927b093ac8f23b47f7189aadb9bc67",
		x"43af1c76126714dfa950c368787c81ae3beecf956c85c962086ae16e40ebb0b4",
		x"0b2aa58ceb3bdb9e1eef66b376e0c565d5d8fe7bacb8da866f859ac521f3d571",
		x"2c2db8f7876685f2cd9a2e0ddb64c9d5bf13905371fc39e0fa86e1477234a297",
		x"e6e5c42cb2d460c9d6e4791a1681bb2e222e54558eb78d5244e217d1bfcf5058",
		x"ae4ef4792ea148608cf116cb2bff66e8fc74811266cd641112cd17801ed38b59",
		x"4b5d27d3368f9c17d4b2a2b216c7e74e7714d2cc03e1e44588cd9936de74357c",
		x"848af9f57eb1a616e2c342c8cea528b8a95a5d16d9d87be9bb3784d0c351c32b",
		x"927547fe5e5e45e2fe99f1651ea1cbf097dc3a3d40ddd21cee260543c288ec6b",
		x"8ff2178ae2dbe5e872fac789a34bc228debf54a882743caad14f3a550fdbe68f",
		x"631f4acb8d3ca4253e301849f157571d3211b6c1045347befb7c77df3c6ca7bd",
		x"93b89385546d71379fe41c39bc602e8b7c8b2f78ee914d1f0af0d437a189a8a4",
		x"a8e4ede4c5fe5e88d4fb192e0a0821e935ba145bbfc59c2508282755a5df53a5",
		x"61cfa42792f93b9fde36eb163e978709fafa7616ec3c7dad0135806c3d91a21b",
		x"2a306354ca3ea90b0e97eaebcea0a6d7c6522399e885c613de824922c892c490",
		x"f72578721db56bf8f49538b0ae6ea470c2fb1339dd26333f135f7def45376ec0",
		x"73bd6978c59f2b219449b36770fb313fbe2da28f6b04275f071a1b193dde2072",  
		x"0000000000000000000000000000000000000000000000000000000000000000"));

	-- added for ROM usage
	constant XILINX : integer := 0;
	constant ALTERA : integer := 1;
	
	constant M512	: integer  := 0;
	constant M4K	: integer  := 1;
	constant M9K	: integer  := 2;
	constant M20K	: integer  := 3;
	constant MLAB	: integer  := 4;
	constant MRAM	: integer  := 5;
	constant M144K	: integer  := 6;	
	
	constant MEM_DISTRIBUTED	: integer := 0; 
	constant MEM_EMBEDDED		: integer := 1;
	constant MEM_LOGIC    		: integer := 2;

end sha3_jh_package;

package body sha3_jh_package is
	function blk2wordmatrix_inv  (signal x : in std_logic_vector(b-1 downto 0) ) return std_logic_matrix is
		variable retval : std_logic_matrix;
	begin
		for i in 0 to 31 loop
			retval(32-1-i) := x(32*(i+1) - 1 downto 32*i);
		end loop;
		return retval;
	end blk2wordmatrix_inv;	
	
	function form_group  (hm : in std_logic_vector; b : integer; cw : integer ) return std_logic_vector is   
		variable g : std_logic_vector(b-1 downto 0);
	begin
		for i in 0 to cw/2-1 loop
			g(b-i*8-1 downto b-i*8-4)   := hm(b-1 - i) & hm(b-1 - (i+cw)) & hm(b-1 - (i+2*cw)) & hm(b-1 - (i+3*cw));
			g(b-i*8-5 downto b-i*8-8)	:= hm(b-1 - (i + cw/2)) & hm(b-1 - ((i+cw) + (cw/2))) & hm(b-1 - (i+2*cw + cw/2)) & hm(b-1 - (i+3*cw + cw/2));			
		end loop; 
		return g;
	end form_group;	 
	
	function degroup  (rd : in std_logic_vector; b : integer; cw : integer ) return std_logic_vector is   
		variable dg : std_logic_vector(b-1 downto 0);
	begin
		for i in 0 to cw/2-1 loop
			dg(b-1 - i) 	   := rd(b-i*8-1);
			dg(b-1 - (i+cw))   := rd(b-i*8-2);
			dg(b-1 - (i+2*cw)) := rd(b-i*8-3);
			dg(b-1 - (i+3*cw)) := rd(b-i*8-4);
			dg(b-1 - (i + cw/2)) 		:= rd(b-i*8-5);
			dg(b-1 - (i+cw + cw/2))		:= rd(b-i*8-6);
			dg(b-1 - (i+2*cw + cw/2))	:= rd(b-i*8-7);
			dg(b-1 - (i+3*cw + cw/2))	:= rd(b-i*8-8);
		end loop; 
		return dg;
	end degroup;	
	
	function get_iv ( h : integer ) return std_logic_vector is
	begin
		if ( h = 256 ) then
			return iv256r3;
		else
			return iv512r3;
		end if;	
	end get_iv;		   
	
	function permute ( ii : std_logic_vector; bw : integer; cw : integer ) return std_logic_vector is
		type array_type is array (0 to cw-1) of std_logic_vector(3 downto 0);
		variable ww, pi, pp, phi : array_type;		   
		variable oo : std_logic_vector(bw-1 downto 0);
	begin		
		inout_gen : for i in bw/4-1 downto 0 loop
			ww(bw/4-1 - i) := ii(i*4+3 downto i*4);  		
		end loop;
	
		pi_gen : for  i in cw/4-1 downto 0 loop
			pi(i*4 + 0) := ww(i*4 + 0);
			pi(i*4 + 1) := ww(i*4 + 1);
			pi(i*4 + 2) := ww(i*4 + 3);
			pi(i*4 + 3) := ww(i*4 + 2);
		end loop;
		
		--pp
		pp_gen : for i in cw/2-1 downto 0 loop
			pp(i)  			:= pi(i*2);
			pp(i + cw/2)	:= pi(i*2 + 1);
		end loop;
		
		-- phi	
		phi_gen1 : for i in cw/2-1 downto 0 loop
			phi(i) := pp(i);
		end loop;
		phi_gen : for i in cw/4-1 downto 0 loop
			phi(i*2 + cw/2)  	:= pp(i*2 + 1 + cw/2);
			phi(i*2 + 1 + cw/2) := pp(i*2 + cw/2);	
		end loop;	   
		
		out_gen : for i in bw/4-1 downto 0 loop
			oo(i*4+3 downto i*4) := phi(bw/4-1 - i);
		end loop;
	
		return oo;
	end permute;
end package body;
