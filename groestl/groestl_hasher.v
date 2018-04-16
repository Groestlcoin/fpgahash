
module Groestl_Hasher (clk,
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
    reg dst_ready = 0;

    wire src_read;
    wire dst_write;

    reg [63:0] din;
    wire [63:0] dout;

    reg dst_write_1;

    //final hash, internal hash
    wire [255:0] final_hash;
    reg [511:0] hash, int_hash;

    reverce reverce(.in(hash[511:256]),.out(final_hash));

    //data reads
    wire [31:0] hash_result;
    wire [31:0] result;

/*
========================================================
regs
*/

  reg [((32*20)-1):0] msg = 0;
  reg [((32*20)-1):0] msg_tmp;
  reg [31:0] target0;
  reg [31:0] target1;
  reg [31:0] nonce_in;
  reg [31:0] nonce_out;
  reg [31:0] golden_nonce;

  reg found_nonce;
  reg find_hash;


/*
=======================================================
module inst.
*/

    groestl_top_pq_parallel #(
        .HS(512)
    ) groestl_inst1(
        .rst        (hash_reset | reset),
        .clk        (clk),
        .src_ready  (src_ready),
        .src_read   (src_read),
        .dst_ready  (dst_ready),
        .dst_write  (dst_write),
        .din        (din),
        .dout       (dout)
    );

    reg src_ready2;
    wire src_read2;
    wire dst_write2;
    reg dst_ready2 = 0;
    reg [63:0] dout_buf;
    reg [63:0] din2;
    wire [63:0] dout2;

    reg dst_write2_1;

//    wire [63:0] header = 64'h8000_0000_0000_0200;

    groestl_top_pq_parallel #(
        .HS(512)
    ) groestl_inst2(
        .rst        (hash_reset | reset),
        .clk        (clk),
        .src_ready  (src_ready2),
        .src_read   (src_read2),
        .dst_ready  (dst_ready2),
        .dst_write  (dst_write2),
        .din        (din2),
        .dout       (dout2)
    );

    reg [3:0] state = 0;
    reg [3:0] outcount = 0;

    always @ (posedge clk) begin
      
      if(reset) begin
        state <= 0;

        din2 <= 0;
        dout_buf <= 64'h8000_0000_0000_0200;
        src_ready2 <= 1;
      end

      else begin

        case(state)

        //waiting for write
          0: begin
            src_ready2 <= 0;
            din2 <= 64'h8000_0000_0000_0200;
            state <= 1;
          end

          1: begin
            src_ready2 <= 1;

            if(dst_write) begin
              src_ready2 <= 0;
              din2 <= dout;
              state <= 2;
            end
          end

          2: begin
            src_ready2 <= 0;
            din2 <= dout;
            if(dst_write == 0) begin
              state <= 3;
            end
          end

          3: begin
            src_ready2 <= 1;
            if(dst_write2) begin
              src_ready2 <= 0;
              din2 <= 64'h8000_0000_0000_0200;
              state <= 1;
            end
          end

        endcase

      end
    end

/*
======================================================
hash output logic
*/

  wire [63:0] dout2_trans = { dout2[7:0], dout2[15:8], dout2[23:16], dout2[31:24], dout2[39:32], dout2[47:40], dout2[55:48], dout2[63:56] };

  always @ (posedge clk) begin

    if(reset) begin
      hash <= 0;
    end

    else begin
      if(dst_write2) begin
        hash[511:0] <= { dout2_trans[63:0], hash[511:64] };
      end
    end
  end

  wire [63:0] dout_trans = { dout[7:0], dout[15:8], dout[23:16], dout[31:24], dout[39:32], dout[47:40], dout[55:48], dout[63:56] };

  always @ (posedge clk) begin

    if(reset) begin
      int_hash <= 0;
    end

    else begin
      if(dst_write) begin
        int_hash[511:0] <= { dout_trans[63:0], int_hash[511:64] };
      end
    end
  end

  always @ (posedge clk) begin
      dst_write_1  <= dst_write;
      dst_write2_1 <= dst_write2;
  end

/*
========================================================
result checking
*/

  always @ (posedge clk) begin
    
    if(reset) begin
      found_nonce <= 0;
      golden_nonce <= 0;
    end

    else begin
      
      //after the last dst_write, signal hash is ready
      if(dst_write2_1 == 1 && dst_write2 == 0) begin
          if(final_hash[255:224] <= target0[31:0] && final_hash[223:192] <= target1[31:0]) begin
            $display("found golden nonce");
            found_nonce <= 1;
            golden_nonce <= nonce_out - 2;
          end
      end

    end

  end

/*
========================================================
msg loading
*/

    reg [3:0] fstate;

    always @ (posedge clk) begin
      
      if(reset) begin
        fstate <= 0;

        din2 <= 0;
        dout_buf <= 64'h8000_0000_0000_0200;
        src_ready2 <= 1;
      end

      else begin

        //msg loading
        if(fstate >= 2 && fstate <= 11) begin
            din <= msg_tmp[63:0];
            msg_tmp <= { 64'h0, msg_tmp[639:64] };          
        end

        case(fstate)
          0: begin
            src_ready <= 1;
            if(find_hash) begin

              //write header
              din <= 64'h8000_0000_0000_0280;
              src_ready <= 0;

              //setup message
              nonce_out <= nonce_in + 1;
              msg_tmp <= { nonce_in[31:0], msg[607:0] };

              //change state
              fstate <= 1;
            end
          end

          //idle cycle
          1: fstate <= 2;

          //load msg in 10 64-bit chunks
          2: fstate <= 3;
          3: fstate <= 4;
          4: fstate <= 5;
          5: fstate <= 6;
          6: fstate <= 7;
          7: fstate <= 8;
          8: fstate <= 9;
          9: fstate <= 10;
          10: fstate <= 11;
          11: fstate <= 12;

          //msg loaded, waiting for result
          12: begin
            src_ready <= 1;

            //load next msg
            if(dst_write == 0 && dst_write_1) begin

              //write header
              din <= 64'h8000_0000_0000_0280;
              src_ready <= 0;

              //setup message
              if((nonce_out + 1) == nonce_in) begin
                finished <= 1;
              end
              nonce_out <= nonce_out + 1;
              msg_tmp <= { nonce_out[31:0], msg[607:0] };

              //change state
              fstate <= 1;

            end

          end

        endcase

      end
    end

/*
========================================================
avalon read
*/

  assign result = 
    (address[4:0] == 5'h0) ? golden_nonce[31:0] :
    (address[4:0] == 5'h1) ? golden_nonce[31:0] :
    (address[4:0] == 5'h2) ? nonce_in[31:0] :
    (address[4:0] == 5'h3) ? nonce_out[31:0] :
    (address[4:0] == 5'h4) ? { 31'h0, found_nonce } :
    0;

  always @ (posedge clk) begin
    if (reset)
      readdata <= 0;
    else if(read == 1 && chipselect == 1)
      readdata <= result;
  end

/*
=========================================================
avalon writes
*/

  always @ (posedge clk) begin
    
    if(reset) begin
      target0 <= 0;
      target1 <= 0;
      nonce_in <= 0;
      hash_reset <= 0;
    end

    else begin
      
      hash_reset <= 0;
      find_hash <= 0;

      if(write == 1 && chipselect == 1) begin
        case(address[4:0])
          5'h00: msg[((32*1)-1):0] <= writedata[31:0];
          5'h01: msg[((32*2)-1):(32*1)] <= writedata[31:0];
          5'h02: msg[((32*3)-1):(32*2)] <= writedata[31:0];
          5'h03: msg[((32*4)-1):(32*3)] <= writedata[31:0];
          5'h04: msg[((32*5)-1):(32*4)] <= writedata[31:0];
          5'h05: msg[((32*6)-1):(32*5)] <= writedata[31:0];
          5'h06: msg[((32*7)-1):(32*6)] <= writedata[31:0];
          5'h07: msg[((32*8)-1):(32*7)] <= writedata[31:0];
          5'h08: msg[((32*9)-1):(32*8)] <= writedata[31:0];
          5'h09: msg[((32*10)-1):(32*9)] <= writedata[31:0];
          5'h0A: msg[((32*11)-1):(32*10)] <= writedata[31:0];
          5'h0B: msg[((32*12)-1):(32*11)] <= writedata[31:0];
          5'h0C: msg[((32*13)-1):(32*12)] <= writedata[31:0];
          5'h0D: msg[((32*14)-1):(32*13)] <= writedata[31:0];
          5'h0E: msg[((32*15)-1):(32*14)] <= writedata[31:0];
          5'h0F: msg[((32*16)-1):(32*15)] <= writedata[31:0];
          5'h10: msg[((32*17)-1):(32*16)] <= writedata[31:0];
          5'h11: msg[((32*18)-1):(32*17)] <= writedata[31:0];
          5'h12: msg[((32*19)-1):(32*18)] <= writedata[31:0];
          5'h13: msg[((32*20)-1):(32*19)] <= writedata[31:0];

          5'h18: target0[31:0]  <= writedata[31:0];
          5'h19: target1[31:0]  <= writedata[31:0];
          5'h1A: { find_hash, nonce_in[31:0] } <= { 1'b1, writedata[31:0] };

          5'h1F: hash_reset <= 1;
        endcase
      end
    end
  end

endmodule

module reverce(in, out);
  input  [255:0] in;
  output [255:0] out;
  
genvar i; 

    generate
          for(i=0; i<32; i=i+1)
            begin : L3
        assign out[(255 - (8*i)):(255 - (8*i)-7)] = in[(8*i)+7:(8*i)];        
            end
    endgenerate  
endmodule