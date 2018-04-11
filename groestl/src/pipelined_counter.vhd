-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity pipelined_counter is
    Generic(osize: integer := 64;
			adder_size : integer := 16);
    Port ( o : out  STD_LOGIC_VECTOR (osize-1 downto 0);
		   clk  : in   STD_LOGIC;
		   rst : in std_logic;
	       en : in std_logic  
			  );
end pipelined_counter;

architecture struct of pipelined_counter is

	constant total_reg : integer := osize/adder_size;	
	constant zeros : std_logic_vector(adder_size-1 downto 0):= (others=>'0');
	
	type reg_type is array (0 to total_reg-1) of std_logic_vector(adder_size-1 downto 0);
	type add_type is array (0 to total_reg-1) of std_logic_vector(adder_size downto 0);
	
	signal reg : reg_type;															
	signal add_result : add_type;			
	
	signal carry : std_logic_vector(total_reg - 1 downto 0);
	
	signal en_propagate : std_logic_vector(total_reg-1 downto 1);
    
    function concat_array ( arr : reg_type ; arr_depth : integer; arr_width : integer ) return std_logic_vector is
        variable ret : std_logic_vector(arr_depth*arr_width - 1 downto 0);
    begin
        for i in 0 to arr_depth-1 loop
            ret(i*arr_width + arr_width - 1 downto i*arr_width) := arr(i);
        end loop;		
		return ret;
    end function concat_array;
begin
	
	add_result(0) <= '0' & reg(0) + carry(0) + 1;
	add_propagate: for i in 1 to total_reg-1 generate
		add_result(i) <= '0' & reg(i) + carry(i);
	end generate;							  
	
	
	
	reg_gen : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then 
				for i in 0 to total_reg-1 loop
					reg(i) <= zeros;
				end loop;				
			else								  				
				if en = '1' then
					reg(0) <= add_result(0)(adder_size-1 downto 0);							
				end if;													
				
				for i in 1 to total_reg-1 loop
					if en_propagate(i) = '1' then
						reg(i) <= add_result(i)(adder_size-1 downto 0);
					end if;
				end loop;															
			end if;
		end if;			
	end process;		
	
	carry_gen : process( clk )
	begin			  
		if rising_edge( clk ) then	  
			for i in 1 to total_reg-1 loop
				carry(i) <= add_result(i-1)(adder_size);
			end loop;
		end if;	
		carry(0) <= '0';
	end process;

	en_gen : process( clk )
	begin
		if rising_edge( clk ) then
			en_propagate(1) <= en;
			for i in 2 to total_reg-1 loop
				en_propagate(i) <= en_propagate(i-1);
			end loop;
		end if;
	end process;
    
    o <= concat_array( reg, total_reg, adder_size );
end struct;
