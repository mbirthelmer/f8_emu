
`include "f8_ops.vh"

module tb_f8_3850_alu;

	reg [3:0] op;
	reg [7:0] left;
	reg [7:0] right;
	reg c_in;
	
	reg [7:0] exp_result;
	wire [7:0] result;
	wire c, z, ov, s;
	reg exp_z, exp_ov, exp_c, exp_s;


	
	f8_3850_alu i_alu(
		.op(op), .left(left), .right(right), .c_in(c_in),
		.result(result), .c(c), .z(z), .ov(ov), .s(s) );

	function [32:0] tests;
	input integer i;
	begin
	case(i)
	0: tests = {`ALU_L, 	8'hab, 8'h00, 1'h1, 8'hab, 1'h0, 1'h0, 1'h0, 1'h0};
	1: tests = {`ALU_L, 	8'h00, 8'h00, 1'h0, 8'h00, 1'h0, 1'h1, 1'h0, 1'h1};
	2: tests = {`ALU_R, 	8'h12, 8'h43, 1'h0, 8'h43, 1'h0, 1'h0, 1'h0, 1'h1};
	3: tests = {`ALU_R, 	8'h12, 8'h00, 1'h0, 8'h00, 1'h0, 1'h1, 1'h0, 1'h1};
	4: tests = {`ALU_SL_1,	8'h81, 8'h00, 1'h0, 8'h02, 1'h0, 1'h0, 1'h0, 1'h1};
	5: tests = {`ALU_SL_4,	8'h81, 8'h00, 1'h0, 8'h10, 1'h0, 1'h0, 1'h0, 1'h1};
	6: tests = {`ALU_SR_1,	8'h81, 8'h00, 1'h0, 8'h40, 1'h0, 1'h0, 1'h0, 1'h1};
	7: tests = {`ALU_SR_4,	8'h81, 8'h00, 1'h0, 8'h08, 1'h0, 1'h0, 1'h0, 1'h1};
	8: tests = {`ALU_LINK,	8'h84, 8'h00, 1'h1, 8'h85, 1'h0, 1'h0, 1'h0, 1'h0};
	9: tests = {`ALU_COM,	8'h8B, 8'h00, 1'h0, 8'h74, 1'h0, 1'h0, 1'h0, 1'h1};
	10: tests = {`ALU_INC,	8'hff, 8'h00, 1'h0, 8'h00, 1'h1, 1'h1, 1'h0, 1'h1};
	11: tests = {`ALU_AND,	8'h36, 8'h2a, 1'h0, 8'h22, 1'h0, 1'h0, 1'h0, 1'h1};
	12: tests = {`ALU_OR,	8'h0a, 8'ha3, 1'h0, 8'hab, 1'h0, 1'h0, 1'h0, 1'h0};
	13: tests = {`ALU_XOR,	8'hab, 8'h42, 1'h0, 8'hE9, 1'h0, 1'h0, 1'h0, 1'h0};
	14: tests = {`ALU_ADD,	8'h3f, 8'h7e, 1'h0, 8'hbd, 1'h0, 1'h0, 1'h1, 1'h0};
	15: tests = {`ALU_CMP,	8'h1b, 8'hd8, 1'h0, 8'hbd, 1'h1, 1'h0, 1'h0, 1'h0};
	16: tests = {`ALU_ADD_BCD, 8'h87, 8'h67, 1'h0, 8'h88, 1'h0, 1'h0, 1'h0, 1'h0};
	17: tests = {`ALU_DEC_R, 8'h00, 8'h17, 1'h0, 8'h16, 1'h1, 1'h0, 1'h0, 1'h1};
	endcase
	end
	endfunction

/* op, left, right, c_in, result, c, z, ov, s */

	integer i;

	initial begin
		$dumpfile("alu.vcd");
		$dumpvars;

		for(i=0; i<18; i=i+1) begin
			#2;
			$display("test %d", i);
			{op, left, right, c_in, exp_result, exp_c, exp_z, exp_ov, exp_s} = tests(i);
			#2;
			if(result != exp_result) $error("Result mismatch");
			if(exp_c != c) $error("Carry mismatch");
			if(exp_z != z) $error("Zero mismatch");
			if(exp_ov != ov) $error("OV mismatch");
			if(exp_s != s) $error("Sign mismatch");
		end

		#10;
		$finish;

	end
	
	/*initial begin
		#10;
		@(negedge clk);
		rst = 0;
		en = 1;
		
		left = 8'hF0;
		right = 8'h0F;
		
		@(negedge clk);
		op = ALU_R;
		
		left = 8'hA5;
		right = 8'h55;
		
		@(negedge clk);
		op = 2;
		
		left = 8'd100;
		right = 8'd135;

		
		@(negedge clk);
		left = 8'd200;
		
		@(negedge clk);
		left = 8'he7;
		right = 8'h9c;
		
		@(negedge clk);
		op = 2;
		left = 8'h21;
		right = 8'h66;
		
		@(negedge clk);
		op = 3;
		left = result;
		right = 8'h67;
		
		@(negedge clk);
		op = 4;
		
		left = 8'h5A;
		right = 8'hAA;
		
		@(negedge clk);
		op = 5;
		
		@(negedge clk);
		op = 6;
		
		left = 8'd50;
		right = 8'd105;
		
		@(negedge clk);
		op = 10;
		
		left = 8'h2;
		
		@(negedge clk);
		op = 9;
		left = result;
		
		@(negedge clk);
		op = 8;
		left = result;
		
		@(negedge clk);
		op = 7;
		left = result;
		
		@(negedge clk);
		$finish;
	end*/
	
endmodule
