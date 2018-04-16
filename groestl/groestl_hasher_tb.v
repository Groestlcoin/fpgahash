module groestl_hasher_tb();

reg clk = 0;
reg reset, write, read, chipselect;
reg [4:0] address;
reg [31:0] writedata;
wire [31:0] readdata;
reg [3:0] byteenable;

Groestl_Hasher uut(clk,
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
	address = 0;
	read = 0;
	write = 0;
	chipselect = 0;

	#10;	address = 5'h00;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h01;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h02;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h03;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h04;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h05;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h06;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h07;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h08;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h09;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h0A;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h0B;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h0C;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h0D;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h0E;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h0F;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h10;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h11;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h12;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;
	#10;	address = 5'h13;	write = 1;	chipselect = 1;	writedata = 32'h00000000;	#10;	write = 0;			chipselect = 0;

	#10;
	address = 5'h18;
	write = 1;
	chipselect = 1;
	writedata = 32'h00000000;
	#10;
	write = 0;
	chipselect = 0;

	#10;
	address = 5'h19;
	write = 1;
	chipselect = 1;
	writedata = 32'hFFFFFFFF;
	#10;
	write = 0;
	chipselect = 0;

	#10;
	address = 5'h1A;
	write = 1;
	chipselect = 1;
	writedata = 32'h00000000;
	#10;
	write = 0;
	chipselect = 0;



	//clear hash_ready flag
	#10000;
	address = 4'h4;
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

	#10;
	address = 5'h10;
	read = 1;
	chipselect = 1;
	#10;
	read = 0;
	chipselect = 0;

	#100;

	$stop;
end

endmodule

