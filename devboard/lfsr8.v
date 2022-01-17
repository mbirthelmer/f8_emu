
module lfsr8(
	input clk,
	
	input en,
	input ld,
	input [7:0] in,
	output reg [7:0] out);
	
	wire lfsr_d;
	
	assign lfsr_d = ~((out[7] ^ out[5]) ^ (out[4] ^ out[3]));
	
	always @(posedge clk) begin
		out <= ld ? in :
				en ? {out[6:0], lfsr_d} :
				out;
	end
endmodule