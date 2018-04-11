module jh_hash_tb();

reg clk = 0;
reg reset, write, read, chipselect;
reg [3:0] address;
reg [31:0] writedata;
wire [31:0] readdata;
reg [3:0] byteenable;

JH_Hash_Component uut(clk,
                      reset,
                      address,
                      writedata,
                      byteenable,
                      write,
                      read,
                      chipselect,
                      readdata);

initial begin
	forever begin
		#5 clk = ~clk;
	end
end

initial begin
	reset = 1;
	
	read = 0;
	write = 0;
	chipselect = 0;

	byteenable = 4'b1111;
	writedata = 0;
	address = 0;

	#100;
	reset = 0;
	address = 4'h10;
	read = 0;
	write = 0;
	chipselect = 0;

	#10;
	address = 4'h8;
	write = 1;
	chipselect = 1;
	writedata = 32'h00000008;
	#10;
	write = 0;
	chipselect = 0;

	#10;
	address = 4'h9;
	write = 1;
	chipselect = 1;
	writedata = 32'h80000000;
	#10;
	write = 0;
	chipselect = 0;

	#10;
	address = 4'h8;
	write = 1;
	chipselect = 1;
	writedata = 32'h00000000;
	#10;
	write = 0;
	chipselect = 0;

	#10;
	address = 4'h9;
	write = 1;
	chipselect = 1;
	writedata = 32'hCC000000;
	#10;
	write = 0;
	chipselect = 0;

	#10000;
	address = 4'hA;
	write = 1;
	chipselect = 1;
	writedata = 32'h00000000;
	#10;
	write = 0;
	chipselect = 0;

	#100;
	address = 4'h0;
	read = 1;
	chipselect = 1;
	#10;
	read = 0;
	chipselect = 0;

	#100;

	$stop;
end

endmodule

