-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity jh_byte_pad is
    generic(w:integer:=64 );
    port 	( 	din : in  STD_LOGIC_VECTOR (w-1 downto 0);
           		dout : out  STD_LOGIC_VECTOR (w-1 downto 0);
			  	sel_pad : in STD_LOGIC_VECTOR (1 downto 0);
			  	sel_pad_location : in STD_LOGIC_VECTOR (7 downto 0);
				sel_din  : in STD_LOGIC_VECTOR (7 downto 0);
			  	clk  : in   STD_LOGIC;
			  	rst : in std_logic;
		     	en_size : in std_logic);
end jh_byte_pad;

architecture struct of jh_byte_pad is		  
	signal dout_wire_byte : STD_LOGIC_VECTOR (w-1 downto 0);
	signal msg_size_wire  : STD_LOGIC_VECTOR (127 downto 0);
	signal din_r : STD_LOGIC_VECTOR (w-1 downto 0);
begin
	din_r <= '0' & din(62 downto 0) ;			
	
	with sel_pad select
	dout <= msg_size_wire(127 downto 64) when "00",
			msg_size_wire(63 downto 0) when "01",
			dout_wire_byte when others;
     			  
	byte_1:entity work.byte_pad(struct)
		generic map ( w => w)	
		port map (din => din , dout => dout_wire_byte , sel_din => sel_din, sel_pad_location => sel_pad_location );
	
	msglen_2:entity work.msg_len(struct)
		generic map ( isize => 64, osize => 128, adder_size => 16 )
	    port map(din => din_r, msg_size => msg_size_wire, clk => clk, rst => rst, en => en_size);	
end struct;
