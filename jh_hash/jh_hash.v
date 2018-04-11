module JH_Hash_Component (clk,
                      reset,
                      address,
                      writedata,
                      byteenable,
                      write,
                      read,
                      chipselect,
                      readdata);

      
  input clk;
  input reset;
  input [3:0] address;
  input [31:0] writedata;
  input [3:0] byteenable;
  input write;
  input read;
  input chipselect;
  output [31:0] readdata;

  reg [31:0] readdata;


/*

when dst_write goes high, it is writing a word on each clock cycle.  it is the result of the previous set of data fed to it.

its "w = 64" and it requires 256 

-------------------

*/
  reg hash_reset;
  reg src_ready;
  reg dst_ready;

  wire src_read;
  wire dst_write;

  reg [63:0] din;
  wire [63:0] dout;

  jh_top jh_top_inst(
    .rst        (hash_reset | reset),
    .clk        (clk),
    .src_ready  (src_ready),
    .src_read   (src_read),
    .dst_ready  (dst_ready),
    .dst_write  (dst_write),
    .din        (din),
    .dout       (dout)
  );

  reg [255:0] hash;
  reg hash_ready;

  always @ (posedge clk) begin
    
    if(reset) begin
      dst_ready <= 0;
    end
    else begin
      dst_ready <= 0;      
    end

  end

  reg dst_write_1;

  wire [63:0] dout_trans;

  assign dout_trans[63:0] = {
    dout[7:0],
    dout[15:8],
    dout[23:16],
    dout[31:24],
    dout[39:32],
    dout[47:40],
    dout[55:48],
    dout[63:56]
  };

  always @ (posedge clk) begin

    if(reset) begin
      hash <= 0;
    end

    else begin
      
      dst_write_1 <= dst_write;
      
      if(dst_write) begin
//        hash[255:0] <= { hash[(255-64):0], dout[63:0] };
        hash[255:0] <= { dout_trans[63:0], hash[255:64] };
      end

    end
  end

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


  wire [31:0] result;

  assign result = 
    (address[3:0] == 4'h0) ? hash[((32*1)-1):0] :
    (address[3:0] == 4'h1) ? hash[((32*2)-1):32*1] :
    (address[3:0] == 4'h2) ? hash[((32*3)-1):32*2] :
    (address[3:0] == 4'h3) ? hash[((32*4)-1):32*3] :
    (address[3:0] == 4'h4) ? hash[((32*5)-1):32*4] :
    (address[3:0] == 4'h5) ? hash[((32*6)-1):32*5] :
    (address[3:0] == 4'h6) ? hash[((32*7)-1):32*6] :
    (address[3:0] == 4'h7) ? hash[((32*8)-1):32*7] :
    (address[3:0] == 4'h8) ? din[31:0] :
    (address[3:0] == 4'h9) ? din[63:32] :
    (address[3:0] == 4'hA) ? { 31'h0, hash_ready } :
    0;

  always @ (posedge clk) begin
    if (reset)
      readdata <= 0;
    else if(read == 1 && chipselect == 1)
      readdata <= result;
  end

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
        if(address[3:0] == 4'b1000) begin
          din[31:0] <= writedata[31:0];          
        end

        //data byte high
        if(address[3:0] == 4'b1001) begin
          din[63:32] <= writedata[31:0];
          src_ready <= 0;
        end

        //data byte low
        if(address[3:0] == 4'b1010) begin
          din[31:0] <= writedata_trans[31:0];          
        end

        //data byte high
        if(address[3:0] == 4'b1011) begin
          din[63:32] <= writedata_trans[31:0];
          src_ready <= 0;
        end

        //hash reset
        if(address[3:0] == 4'b1111) begin
          hash_reset <= 1;
        end

      end

    end

  end

endmodule
