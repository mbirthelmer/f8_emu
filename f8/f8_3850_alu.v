
`include "f8_ops.vh"

module f8_3850_alu(
	input [3:0] op,
	input [7:0] left,
	input [7:0] right,
	input c_in,
	output reg [7:0] result,
	output reg c,
	output z,
	output ov,
	output s
);

	assign z = ~|result;
	
	wire [7:0] sum;
	wire c_sum;
	reg [7:0] add_x, add_y;
	reg t1, t2;
	reg [7:0] t_bcd;
	
	wire [3:0] bcd_l, bcd_u;
	wire bcd_cl, bcd_cu;
	
	assign {bcd_cl, bcd_l} = left[3:0] + right[3:0];
	assign {bcd_cu, bcd_u} = left[7:4] + right[7:4];
	
	assign {c_sum, sum} = add_x + add_y;
	assign ov = (add_x[7] == add_y[7]) && (add_x[7] != sum[7]);
	assign s = ~result[7];

	always @(*) begin
		case(op)
		`ALU_LINK, `ALU_INC, `ALU_ADD, `ALU_CMP, `ALU_DEC_R: c = c_sum;
		default: c = 1'b0;
		endcase
	end 
	
	always @(*) begin
		add_x = left;
		add_y = right;
		t1 = 1'b0;
		t2 = 1'b0;
		t_bcd = 8'h0;
		
		case(op)
		`ALU_L: result = left;
		`ALU_R: result = right;
		`ALU_SL_1: result = {left[6:0], 1'b0};
		`ALU_SR_1: result = {1'b0, left[7:1]};
		`ALU_SL_4: result = {left[3:0], 4'h0};
		`ALU_SR_4: result = {4'h0, left[7:4]};
		`ALU_LINK: begin
			add_y = c_in;
			result = sum;
		end
		`ALU_COM: result = ~left;
		`ALU_INC: begin
			add_y = 8'h1;
			result = sum;
		end
		`ALU_AND: result = left & right;
		`ALU_OR: result = left | right;
		`ALU_XOR: result = left ^ right;
		`ALU_ADD: result = sum;
		`ALU_CMP: begin
			result = sum;
			add_x = ~left + 1;
		end
		`ALU_ADD_BCD: begin
			/* add_x = {bcd_u, bcd_l};
			add_y = {bcd_cu ? 4'h0 : 4'ha, bcd_cl ? 4'h0 : 4'ha}; */
			result[7:4] = bcd_u + (bcd_cu ? 4'h0 : 4'ha);
			result[3:0] = bcd_l + (bcd_cl ? 4'h0 : 4'ha);
			
		end
		`ALU_DEC_R: begin
			add_x = 8'hff;
			result = sum;
		end
		endcase
	end
	
endmodule