module Keccak_Component (clk,
                      reset,
                      address,
                      writedata,
                      byteenable,
                      write,
                      read,
                      chipselect,
                      readdata);

/*
========================================================
parameters:

  hash_size - size of output hash in bits (used in instantiation of the hash module)

*/
  parameter hash_size = 512;

/*
========================================================
module connections
*/
      
  input clk;
  input reset;
  input [4:0] address;
  input [31:0] writedata;
  input [3:0] byteenable;
  input write;
  input read;
  input chipselect;
  output [31:0] readdata;

  reg [31:0] readdata;

/*
=======================================================
reg/wire defintions
*/


    //hash module connections
    reg hash_reset;
    reg src_ready;
    reg dst_ready;

    wire src_read;
    wire dst_write;

    reg [63:0] din;
    wire [63:0] dout;

    //hash
    reg [hash_size-1:0] hash;
    reg hash_ready;

    //data reads
    wire [31:0] hash_result;
    wire [31:0] result;

    reg dst_write_1;

/*
=======================================================
module inst.
*/

    keccak_top #(
        .HS(hash_size) //HASH_SIZE_256
    ) keccak_inst(
        .rst        (hash_reset | reset),
        .clk        (clk),
        .src_ready  (src_ready),
        .src_read   (src_read),
        .dst_ready  (dst_ready),
        .dst_write  (dst_write),
        .din        (din),
        .dout       (dout)
    );

/*
======================================================
hash output logic
*/

    generate
    if(hash_size == 256)
        assign hash_result =
            (address[3:0] == 4'h0) ? hash[((32*1)-1):0] :
            (address[3:0] == 4'h1) ? hash[((32*2)-1):32*1] :
            (address[3:0] == 4'h2) ? hash[((32*3)-1):32*2] :
            (address[3:0] == 4'h3) ? hash[((32*4)-1):32*3] :
            (address[3:0] == 4'h4) ? hash[((32*5)-1):32*4] :
            (address[3:0] == 4'h5) ? hash[((32*6)-1):32*5] :
            (address[3:0] == 4'h6) ? hash[((32*7)-1):32*6] :
            (address[3:0] == 4'h7) ? hash[((32*8)-1):32*7] :
            0;
    else
        assign hash_result =
            (address[3:0] == 4'h0) ? hash[((32*1)-1):0] :
            (address[3:0] == 4'h1) ? hash[((32*2)-1):32*1] :
            (address[3:0] == 4'h2) ? hash[((32*3)-1):32*2] :
            (address[3:0] == 4'h3) ? hash[((32*4)-1):32*3] :
            (address[3:0] == 4'h4) ? hash[((32*5)-1):32*4] :
            (address[3:0] == 4'h5) ? hash[((32*6)-1):32*5] :
            (address[3:0] == 4'h6) ? hash[((32*7)-1):32*6] :
            (address[3:0] == 4'h7) ? hash[((32*8)-1):32*7] :
            (address[3:0] == 4'h8) ? hash[((32*9)-1):32*8] :
            (address[3:0] == 4'h9) ? hash[((32*10)-1):32*9] :
            (address[3:0] == 4'hA) ? hash[((32*11)-1):32*10] :
            (address[3:0] == 4'hB) ? hash[((32*12)-1):32*11] :
            (address[3:0] == 4'hC) ? hash[((32*13)-1):32*12] :
            (address[3:0] == 4'hD) ? hash[((32*14)-1):32*13] :
            (address[3:0] == 4'hE) ? hash[((32*15)-1):32*14] :
            (address[3:0] == 4'hF) ? hash[((32*16)-1):32*15] :
            0;
    endgenerate


  always @ (posedge clk) begin
    
    if(reset) begin
      dst_ready <= 0;
    end
    else begin
      dst_ready <= 0;      
    end

  end


  wire [63:0] dout_trans = { dout[7:0], dout[15:8], dout[23:16], dout[31:24], dout[39:32], dout[47:40], dout[55:48], dout[63:56] };

  always @ (posedge clk) begin

    if(reset) begin
      hash <= 0;
    end

    else begin
      
      
      if(dst_write) begin
//        hash[255:0] <= { dout_trans[63:0], hash[255:64] };
        hash[hash_size-1:0] <= { dout_trans[63:0], hash[hash_size-1:64] };
      end

    end
  end

  always @ (posedge clk)
      dst_write_1 <= dst_write;

  always @ (posedge clk) begin
    
    if(reset) begin
      hash_ready <= 0;
    end

    else begin
      
      //after the last dst_write, signal hash is ready
      if(dst_write_1 == 1 && dst_write == 0)
        hash_ready <= 1;

      //any write clears the hash_ready flag
      if(write == 1 && chipselect == 1) begin
        hash_ready <= 0;
      end

    end

  end


/*
========================================================
avalon read
*/

  assign result = 
    (address[3:0] == 4'h0) ? din[31:0] :
    (address[3:0] == 4'h1) ? din[63:32] :
    (address[3:0] == 4'h4) ? { 31'h0, hash_ready } :
    0;

  always @ (posedge clk) begin
    if (reset)
      readdata <= 0;
    else if(read == 1 && chipselect == 1)
      readdata <= address[4] == 1 ? hash_result : result;
  end

/*
=========================================================
avalon writes
*/

  wire [31:0] writedata_trans;

  assign writedata_trans = { writedata[7:0], writedata[15:8], writedata[23:16], writedata[31:24] };

  always @ (posedge clk) begin
    
    if(reset) begin
      src_ready <= 1;
      hash_reset <= 0;
    end

    else begin
      
      src_ready <= 1;
      hash_reset <= 0;

      if(write == 1 && chipselect == 1) begin
        
        //data byte low
        if(address[4:0] == 4'b00000) begin
          din[31:0] <= writedata[31:0];          
        end

        //data byte high
        if(address[4:0] == 4'b00001) begin
          din[63:32] <= writedata[31:0];
          src_ready <= 0;
        end

        //data byte low
        if(address[4:0] == 4'b00010) begin
          din[31:0] <= writedata_trans[31:0];          
        end

        //data byte high
        if(address[4:0] == 4'b00011) begin
          din[63:32] <= writedata_trans[31:0];
          src_ready <= 0;
        end

        //hash reset
        if(address[4:0] == 4'b01111) begin
          hash_reset <= 1;
        end

      end

    end

  end

endmodule
