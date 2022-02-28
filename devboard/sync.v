module sync 
(
	input clk,
	input rst,
	input d,
	output q);
	
	reg [2:0] sr;
	assign q = sr[2];
	
	always @(posedge clk or posedge rst) begin
		if(rst) sr <= 3'd0;
		else sr <= {sr[1:0], d};
	end
endmodule