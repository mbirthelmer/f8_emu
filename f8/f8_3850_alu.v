
`include "f8_ops.vh"

module f8_3850_alu(
	input [3:0] op,
	input [7:0] left,
	input [7:0] right,
	input c_in,
	output reg [7:0] result,
	output reg c,
	output z,
	output reg ov,
	output s
);

	assign z = ~|result;
	
	//reg [7:0] sum, bcd_sum;
	//reg c_sum, c_bcd;
	//reg [7:0] add_x, add_y;

	//wire [3:0] bcd_l, bcd_u;
	//wire bcd_cl, bcd_cu;
	
	//assign {bcd_cl, bcd_l} = left[3:0] + right[3:0];
	//assign {bcd_cu, bcd_u} = left[7:4] + right[7:4];
	//assign bcd_sum[3:0] = bcd_l + (bcd_cl ? 4'h0 : 4'ha);
	//assign {c_bcd, bcd_sum[7:4]} = bcd_u + {3'd0, bcd_cl} + (bcd_cu ? 4'h0 : 4'ha);
	
	//assign {c_sum, sum} = add_x + add_y;
	//assign ov = (add_x[7] == add_y[7]) && (add_x[7] != sum[7]);
	assign s = ~result[7];

/*
	always @(*) begin
		case(op)
		`ALU_LINK, `ALU_INC, `ALU_ADD, `ALU_CMP, `ALU_DEC_R: c = c_sum;
		//`ALU_ADD_BCD: c = ~c_bcd;
		default: c = 1'b0;
		endcase
	end */

	reg [3:0] bcd_l, bcd_u;
	reg bcd_cl, bcd_cu;
	reg t;

	task add;
	input [7:0] a, b;
	begin
		{t, result[6:0]} = a[6:0] + b[6:0];
		{c, result[7]} = t + a[7] + b[7];

		ov = c ^ t;
	end
	endtask

	task add_bcd;
	input [7:0] a, b;
	begin
		{bcd_cl, bcd_l} = a[3:0] + b[3:0];
		{bcd_cu, bcd_u} = a[7:4] + b[7:4] + bcd_cl;

		result[3:0] = bcd_l + (bcd_cl ? 4'h0 : 4'ha);
		result[7:4] = bcd_u + (bcd_cu ? 4'h0 : 4'ha);
		c = bcd_cu;
	end
	endtask
	
	always @(*) begin
		//add_x = left;
		//add_y = right;
		result = 8'h00;
		c = 1'b0;
		ov = 1'b0;
		t = 1'b0;
		bcd_l = 4'h0;
		bcd_u = 4'h0;
		bcd_cl = 1'b0;
		bcd_cu = 1'b0;

		case(op)
		`ALU_L: result = left;
		`ALU_R: result = right;
		`ALU_SL_1: result = {left[6:0], 1'b0};
		`ALU_SR_1: result = {1'b0, left[7:1]};
		`ALU_SL_4: result = {left[3:0], 4'h0};
		`ALU_SR_4: result = {4'h0, left[7:4]};
		`ALU_LINK: begin
			//add_y = c_in;
			//result = sum;
			add(left, {7'h0, c_in});
		end
		`ALU_COM: result = ~left;
		/*`ALU_INC: begin
			add_y = 8'h1;
			result = sum;
		end */
		`ALU_INC: add(left, 8'h1);
		`ALU_AND: result = left & right;
		`ALU_OR: result = left | right;
		`ALU_XOR: result = left ^ right;
		`ALU_ADD: add(left, right);
		`ALU_CMP: add(~left + 1, right); /* begin
			result = sum;
			add_x = ~left + 1;
		end */
		`ALU_ADD_BCD: begin
			add_bcd(left, right);
			/* add_x = {bcd_u, bcd_l};
			add_y = {bcd_cu ? 4'h0 : 4'ha, bcd_cl ? 4'h0 : 4'ha}; */
			//result = bcd_sum;
			
		end
		`ALU_DEC_R: begin
			//add_x = 8'hff;
			add(8'hff, right);
			//result = sum;
		end
		endcase
	end
	
endmodule