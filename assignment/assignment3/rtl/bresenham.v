module bresenham(
  input clk,
  input resetn,
  input [8:0] x0,
  input [7:0] y0,
  input [8:0] x1,
  input [7:0] y1,
  inout [15:0] color,
  input go,
  input write_finish,
  output [31:0] pixel_address,
  output draw,
  output done
  );

`define WAIT 2'b00
`define CALC 2'b01
`define PIXV 2'b10
`define DONE 2'b11

// wire comparison is unsigned
wire is_steep = (y1 - y0) > (x1 - x0);
wire [8:0] x0_in, x1_in, x0_swap, x1_swap, x0_steep, x1_steep;
wire [8:0] y0_in, y1_in, y0_swap, y1_swap, y0_steep, y1_steep;

assign x0_steep = is_steep ? y0 : x0;
assign y0_steep = is_steep ? x0 : y0;

assign x1_steep = is_steep ? y1 : x1;
assign y1_steep = is_steep ? x1 : y1;

assign x0_in = (x0_steep > x1_steep) ? y0_steep : x0_steep;
assign y0_in = (x0_steep > x1_steep) ? x0_steep : y0_steep;

assign x1_in = (x0_steep > x1_steep) ? y1_steep : x1_steep;
assign y1_in = (x0_steep > x1_steep) ? x1_steep : y1_steep;

/*
maybe put this in the wait state
dffare #(9) input_ff(.clk(clk), .r(resetn), .en(go), .d(x0_swap), .q(x0_in));
dffare #(9) input_ff(.clk(clk), .r(resetn), .en(go), .d(x1_swap), .q(x1_in));
dffare #(8) input_ff(.clk(clk), .r(resetn), .en(go), .d(y0_swap), .q(y0_in));
dffare #(8) input_ff(.clk(clk), .r(resetn), .en(go), .d(y1_swap), .q(y1_in));
*/

reg [1:0] next;
wire [1:0] current;

reg [8:0] next_pix_x;
wire [8:0] pix_x;

reg [8:0] next_pix_y;
wire [8:0] pix_y;

wire [8:0] deltax = x1 - x0;
wire [8:0] deltay = y1 - y0;
wire signed [31:0] error;
reg signed [31:0] next_error;
reg [31:0] next_addr;

wire signed [8:0] y_step = (y0 < y1) ? 1 : -1;
// use wire for current pixel and pix_addr
always@(posedge clk) begin
  case(current)
    `WAIT: next = go ? `CALC : `WAIT;
    `CALC: begin
      next_pix_x = pix_x + 1;
      next_addr = is_steep ? (pix_y << 1) + (pix_x << 10) : (pix_x << 1) + (pix_y << 10);
      next = `PIXV;
      next_error = error + deltay;
      if(next_error >= 0) begin
		  next_pix_y = pix_y + y_step;
        next_error = error + deltay - deltax;
      end
    end
    `PIXV: begin
      //draw = 1'b1;
      next = write_finish ? ((pix_x ==  x1_in) ? `DONE : `CALC) : `PIXV;
      //need extra state for only one cycle assert?
    end
    `DONE: begin
      next = `WAIT;
      //done = 1'b1;
    end
    default: next = `WAIT;
  endcase
end

assign pix_x = (go | ~resetn) ? x0_in : next_pix_x;
assign pix_y = (go | ~resetn) ? y0_in : next_pix_y;
assign error = (go | ~resetn) ? (~deltax + 1) >> 1 : next_error;
assign pixel_address = (go | ~resetn) ? 0 : next_addr;
assign done = (current == `DONE);
assign draw = (current == `PIXV);

endmodule




