
`include "f8_ops.vh"

module f8_3850 (
	output reg [4:0] romc,
	input [7:0] db_in,
	output reg [7:0] db_out,
	output reg db_t,
	
	output write,
	output clk_phi,
	input clk,
	input clk_delay,
	
	input [7:0] io0_in,
	output reg [7:0] io0_out,

	input [7:0] io1_in,
	output reg [7:0] io1_out,
	 
	input ext_res_n,
	input int_req_n,
	
	output icb_n );

	wire [7:0] result;
	wire [7:0] alu_res;
	
	reg [7:0] idata;

	wire [7:0] status;

	reg [3:0] alu_op;
	reg [7:0] lbus, rbus;
	reg [7:0] acc;
	reg [5:0] w;
	reg z, ov, c, s, icb;
	wire alu_z, alu_ov, alu_c, alu_s;
	
	reg [5:0] isar, isar_d;
	reg isar_we;
	reg [5:0] isar_r, isar_a;
	
	reg [7:0] scratchpad[63:0], scr_q, scr_d;
	reg [5:0] scr_raddr, scr_waddr;
	reg scr_we, scr_re;
	
	reg acc_we, new_icb;
	reg db_we, db_re;
	reg [3:0] alu_stat, new_stat;
	
	reg [1:0] io_we, io_re;
			
	reg [7:0] opcode;
	reg [2:0] instr, instr_next;
	reg instr_last;
	reg [2:0] cycle;
	reg op_long;

	reg [4:0] romc_pre;

	reg disallow_irq;
	reg sampled_irq;
	reg do_irq;

	assign clk_phi = clk_delay; // this is a clock that's delayed to meet the td1/td2 skew while the rising edge of clk coincides with rising edge of WRITE
	
	localparam RBUS_SCR = 3'd0, RBUS_ISAR = 3'd1, RBUS_INST = 3'd2, 
				RBUS_IDATA = 3'd3;
	localparam LBUS_ACC = 2'd0, LBUS_STATUS = 2'd1, LBUS_CONST_F = 2'd2, LBUS_CONST_0 = 2'd3;
	
	reg [2:0] rbus_sel;
	reg [1:0] lbus_sel;
	
	wire last_cycle;
	assign last_cycle = (!op_long && cycle == 3'h3) || (cycle == 3'h5);
	
	assign icb_n = ~icb;

	assign status = {3'b0, icb, ov, z, c, s};
	
	//reg rst_fe, rst_re, rst_re_d, rst_done;
	reg ext_res_n_d, rst_done;

	always @(negedge clk) begin
		romc <= romc_pre;
	end
	
	always @(posedge clk) begin
		if(scr_re && cycle == 0) begin
			scr_q <= scratchpad[scr_raddr];
		end
		
		if(scr_we && last_cycle) begin
			scratchpad[scr_waddr] <= result;
		end
	end

	always @(*) begin
		if(db_re) idata = db_in;
		else if(io_re[0]) idata = ~io0_in;
		else if(io_re[1]) idata = ~io1_in;
		else idata = 8'h00;
	end
	
	assign write = last_cycle;

	initial begin
		cycle = 3'd0;
		ext_res_n_d = 1'b0;
		rst_done = 1'b0;
		instr = 0;
	end

	always @(posedge clk) begin
		cycle <= cycle + 1;

		if(cycle == 0) begin
			if(db_re || instr_last) db_t <= 1'b1;
		end else if(cycle == 1) begin
			if(db_we && (alu_op == `ALU_L) && (lbus_sel == LBUS_ACC)) begin 
				// td1
				db_t <= 1'b0;
				db_out <= result;
			end
			sampled_irq <= ~int_req_n;
		end else if(cycle == 2) begin
			if(db_we) begin
				// td2
				db_t <= 1'b0;
				db_out <= result;
			end
			if(io_we[0]) io0_out <= ~result;
			if(io_we[1]) io1_out <= ~result;
		end else if( last_cycle ) begin
			//db_t <= 1'b1;
			
			if(instr_last) begin
				rst_done <= 1'b1;
				opcode <= db_in;
				instr <= 3'd0;

				do_irq <= ~disallow_irq & sampled_irq & icb;

				rst_done <= 1'b1;
			end else
				instr <=  instr_next;
																		
			if(acc_we) acc <= result;

			if(isar_we) isar <= isar_d;

			{ov, z, c, s} <= (new_stat & ~alu_stat) | (alu_stat & {alu_ov, alu_z, alu_c, alu_s});

			icb <= new_icb;
			
			cycle <= 3'h0;

			ext_res_n_d <= ext_res_n;
			if(!ext_res_n) rst_done <= 1'b0;
		end
	end
	
	task scr_read(input [5:0] addr);
	begin
		scr_raddr = addr;
		scr_re = 1'b1;
		rbus_sel = RBUS_SCR;
	end
	endtask
	
	task scr_write(input [5:0] addr);
	begin
		scr_waddr = addr;
		scr_we = 1'b1;
	end
	endtask
	
	task db_read();
	begin
		rbus_sel = RBUS_IDATA;
		db_re = 1'b1;
	end
	endtask
	
	task db_write();
	begin
		db_we = 1'b1;
	end
	endtask
	
	task io_read(input port);
	begin
		rbus_sel = RBUS_IDATA;
		io_re[port] = 1'b1;
	end
	endtask
	
	task io_write(input port);
	begin
		io_we[port] = 1'b1;
	end
	endtask
	
	task instr_romc(input [4:0] _romc);
	begin
		romc_pre = _romc;
		if(_romc == 5'h00 || _romc == 5'h0d || _romc == 5'h1c || _romc == 5'h1d)
			op_long = 1'b0;
		else
			op_long = 1'b1;
	end
	endtask

	task acc_write();
	begin
		acc_we = 1'b1;
	end
	endtask
	
	task acc_read();
	begin
		lbus_sel = LBUS_ACC;
	end
	endtask
	
	task status_read();
	begin
		lbus_sel = LBUS_STATUS;
	end
	endtask
	
	task isar_read();
	begin
		rbus_sel = RBUS_ISAR;
	end
	endtask
	
	function [5:0] op_isar(input [7:0] opcode);
	begin
		if(opcode[3:0] <= 4'hB) begin
			op_isar = opcode[3:0];
		end else if(opcode[3:0] == 4'hC) begin
			op_isar = isar;
		end else if(opcode[3:0] == 4'hD) begin
			isar_we = 1'b1;
			isar_d = {isar[5:3], isar[2:0] + 3'd1};
			op_isar = isar;
		end else if(opcode[3:0] == 4'hE) begin
			isar_we = 1'b1;
			isar_d = {isar[5:3], isar[2:0] - 3'd1};
			op_isar = isar;
		end else op_isar = 6'h00;
	end
	endfunction
	
	always @(*) begin
		case(rbus_sel)
		RBUS_SCR: rbus = scr_q;
		RBUS_INST: rbus = opcode;
		RBUS_ISAR: rbus = {2'b0, isar};
		RBUS_IDATA: rbus = idata;
		default: rbus = 8'h0;
		endcase
		
		case(lbus_sel)
		LBUS_ACC: lbus = acc;
		LBUS_STATUS: lbus = status;
		LBUS_CONST_F: lbus = 8'h0f;
		LBUS_CONST_0: lbus = 8'h00;
		endcase
	end
	
	task do_instr_last();
	begin
		instr_last = 1'b1;
		if(~disallow_irq & sampled_irq & icb) begin
			romc_pre = 5'h10;
			op_long = 1'b1;
		end else begin
			romc_pre = 5'h00;
			op_long = 1'b0;
		end
	end
	endtask

	always @(*) begin
		lbus_sel = LBUS_ACC;
		rbus_sel = RBUS_SCR;
		
		alu_op = `ALU_L;
		
		new_icb = icb;
		alu_stat = 4'h0;
		new_stat = {ov, z, c, s};

		acc_we = 1'b0;
		
		scr_re = 1'b0;
		scr_we = 1'b0;
		scr_raddr = isar;
		scr_waddr = isar;
		
		isar_we = 1'b0;
		isar_d = 6'h00;

		romc_pre = 5'h0;
		
		op_long = 1'b0;
		
		instr_last = 1'b0;
		instr_next = instr + 1;
		
		db_we = 1'b0;
		db_re = 1'b0;
		io_we = 2'b0;
		io_re = 2'b0;

		disallow_irq = 1'b0;
		
		if(!rst_done) begin
			new_icb = 1'b0;	
			case(instr)
			0: begin
				instr_romc(5'h1c);
				instr_next <= ext_res_n_d ? 1 : 0;
				lbus_sel = LBUS_CONST_0;
				//alu_op = `ALU_COM;
				acc_write();
				io_we = 2'b11;
				isar_we = 1'b1;
			end
			1: begin
				instr_romc(5'h08);
				db_write();
				alu_op = `ALU_L;
				lbus_sel = LBUS_CONST_0;
			end
			2: do_instr_last();
			endcase
		end else if(do_irq) begin
			new_icb = 1'b0;	
			case(instr)
			0: instr_romc(5'h1c);
			1: instr_romc(5'h0f);
			2: instr_romc(5'h13);
			3: do_instr_last();
			endcase
		end else begin
			casex(opcode)
			`OP_LR_A_KU: begin
				scr_read(6'd12);
				acc_write();
				alu_op = `ALU_R;
				do_instr_last();				
			end
			`OP_LR_A_KL: begin
				scr_read(6'd13);
				acc_write();
				alu_op = `ALU_R;
				do_instr_last();			
			end
			`OP_LR_A_QU: begin
				scr_read(6'd14);
				acc_write();
				alu_op = `ALU_R;
				do_instr_last();				
			end
			`OP_LR_A_QL: begin
				scr_read(6'd15);
				acc_write();
				alu_op = `ALU_R;
				do_instr_last();				
			end
			`OP_LR_KU_A: begin
				scr_write(6'd12);
				acc_read();
				do_instr_last();				
			end
			`OP_LR_KL_A: begin
				scr_write(6'd13);
				acc_read();
				do_instr_last();				
			end
			`OP_LR_QU_A: begin
					scr_write(6'd14);
					acc_read();
					do_instr_last();				
				end
			`OP_LR_QL_A: begin
					scr_write(6'd15);
					acc_read();
					do_instr_last();				
				end
			`OP_LR_K_P: begin
				case(instr)
				0: begin
					instr_romc(5'h07);
					db_read();
					scr_write(6'd12);
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h0b);
					db_read();
					scr_write(6'd13);
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
			`OP_LR_P_K: begin
				case(instr)
				0: begin
					instr_romc(5'h15);
					scr_read(6'd12);
					db_write();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h18);
					scr_read(6'd13);
					db_write();
					alu_op =`ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_A_IS: begin
				isar_read();
				acc_write();
				alu_op = `ALU_R;
				do_instr_last();
			end
		`OP_LR_IS_A: begin
				isar_d = acc[5:0];
				isar_we = 1'b1;
				do_instr_last();
			end
		`OP_PK: begin
				case(instr)
				0: begin
					instr_romc(5'h12);
					scr_read(6'd13);
					db_write();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h14);
					scr_read(6'd12);
					db_write();
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_P0_Q: begin
				disallow_irq = 1'b1;
				case(instr)
				0: begin
					instr_romc(5'h17);
					scr_read(6'd15);
					db_write();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h14);
					scr_read(6'd14);
					db_write();
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_Q_DC: begin
				case(instr)
				0: begin
					instr_romc(5'h06);
					db_read();
					scr_write(6'd14);
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h09);
					db_read();
					scr_write(6'd15);
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_DC_Q: begin
				case(instr)
				0: begin
					instr_romc(5'h16);
					scr_read(6'd14);
					db_write();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h19);
					scr_read(6'd15);
					db_write();
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_DC_H: begin
				case(instr)
				0: begin
					instr_romc(5'h16);
					scr_read(6'd10);
					db_write();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h19);
					scr_read(6'd11);
					db_write();
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_H_DC: begin
				case(instr)
				0: begin
					instr_romc(5'h06);
					scr_write(6'd10);
					db_read();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h09);
					scr_write(6'd11);
					db_read();
					alu_op = `ALU_R;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_SR_1, `OP_SR_4: begin
				do_instr_last();
				acc_read();
				acc_write();
				alu_stat = 4'b0100;
				new_stat = 4'b0001;
				alu_op = (opcode ==`OP_SR_1) ? `ALU_SR_1 : `ALU_SR_4;
			end
		`OP_SL_1,`OP_SL_4: begin
				do_instr_last();
				acc_read();
				acc_write();
				alu_stat = 4'b0101;
				new_stat = 4'b0000;
				alu_op = (opcode ==`OP_SL_1) ? `ALU_SL_1 : `ALU_SL_4;
			end
		`OP_LM: begin
				case(instr)
				0: begin
					instr_romc(5'h02);
					acc_write();
					db_read();
					alu_op = `ALU_R;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_ST: begin
				case(instr)
				0: begin
					instr_romc(5'h05);
					acc_read();
					db_write();
					alu_op = `ALU_L;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_COM: begin
				do_instr_last();
				acc_read();
				acc_write();
				alu_op = `ALU_COM;
				alu_stat = 4'b0101;
				new_stat = 4'b0000;
			end
		`OP_LNK: begin
				do_instr_last();
				acc_read();
				acc_write();
				alu_op = `ALU_LINK;
				alu_stat = 4'b1111;
			end
		`OP_DI: begin
				case(instr)
				0: begin
					instr_romc(5'h1c);
					new_icb = 1'b0;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_EI: begin
				disallow_irq = 1'b1;
				case(instr)
				0: begin
					instr_romc(5'h1c);
					new_icb = 1'b1;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_POP: begin
				disallow_irq = 1'b1;
				case(instr)
				0: instr_romc(5'h04);
				1: do_instr_last();
				endcase
			end
		`OP_LR_W_J: begin
				disallow_irq = 1'b1;
				case(instr)
				0: begin
					instr_romc(5'h1c);
					scr_read(6'd9);
					new_icb = scr_q[4];
					new_stat = scr_q[3:0];
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_LR_J_W: begin
				do_instr_last();
				status_read();
				scr_write(6'd9);
				alu_op = `ALU_L;
			end
		`OP_INC: begin
				do_instr_last();
				acc_read();
				acc_write();
				alu_op = `ALU_INC;
				alu_stat = 4'b1111;	
			end
		`OP_LI: begin
				case(instr)
				0: begin
					instr_romc(5'h03);
					acc_write();
					db_read();
					alu_op = `ALU_R;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_NI,`OP_OI,`OP_XI: begin
				case(instr)
				0: begin
					instr_romc(5'h03);
					acc_write();
					db_read();
					case(opcode)
					`OP_NI: alu_op = `ALU_AND;
					`OP_OI: alu_op = `ALU_OR;
					`OP_XI: alu_op = `ALU_XOR;
					endcase
					alu_stat = 4'b0101;
					new_stat = 4'b0000;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_AI: begin
				case(instr)
				0: begin
					instr_romc(5'h03);
					acc_write();
					db_read();
					alu_op = `ALU_ADD;
					alu_stat = 4'b1111;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_CI: begin
				case(instr)
				0: begin
					instr_romc(5'h03);
					db_read();
					alu_op = `ALU_CMP;
					alu_stat = 4'b1111;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_IN: begin
				case(instr)
				0: begin
					instr_romc(5'h03);
				end
				1: begin
					instr_romc(5'h1b);
					db_read();
					acc_write();
					alu_op = `ALU_R;
					alu_stat = 4'b0101;
					new_stat = 4'b0000;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_OUT: begin
				disallow_irq = 1'b1;
				case(instr)
				0: begin
					instr_romc(5'h03);
				end
				1: begin
					instr_romc(5'h1a);
					acc_read();
					db_write();
					alu_op = `ALU_L;
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_PI: begin
				disallow_irq = 1'b1;
				case(instr)
				0: begin
					instr_romc(5'h03);
					acc_write();
					db_read();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h0d);
				end
				2: begin
					instr_romc(5'h0c);
				end
				3: begin
					instr_romc(5'h14);
					acc_read();
					db_write();
					alu_op = `ALU_L;
				end
				4: begin
					do_instr_last();
				end
				endcase
			end
		`OP_JMP: begin
				disallow_irq = 1'b1;
				case(instr)
				0: begin
					instr_romc(5'h03);
					acc_write();
					db_read();
					alu_op = `ALU_R;
				end
				1: begin
					instr_romc(5'h0c);
				end
				2: begin
					instr_romc(5'h14);
					acc_read();
					db_write();
					alu_op = `ALU_L;
				end
				3: begin
					do_instr_last();
				end
				endcase
			end
		`OP_DCI: begin
				case(instr)
				0: begin
					instr_romc(5'h11);
				end
				1,3: begin
					instr_romc(5'h03);
					op_long = 1'b0;
				end
				2: begin
					instr_romc(5'h0e);
				end
				4: begin
					do_instr_last();
				end
				endcase
			end
		`OP_NOP: begin
				do_instr_last();
			end
		`OP_XDC: begin
				case(instr)
				0: instr_romc(5'h1d);
				1: do_instr_last();
				endcase
			end
		`OP_DS: begin
				do_instr_last();
				op_long = 1'b1;

				scr_read( op_isar(opcode) );
				scr_write( op_isar(opcode) );
				alu_op = `ALU_DEC_R;
				
				alu_stat = 4'b1111;
			end
		`OP_LR_A_R: begin
				do_instr_last();
				scr_read( op_isar(opcode) );
				acc_write();
				alu_op = `ALU_R;
			end
		`OP_LR_R_A: begin
				do_instr_last();
				scr_write( op_isar(opcode) );
				acc_read();
				alu_op = `ALU_L;
			end
		`OP_LISU: begin
				do_instr_last();
				isar_d = {opcode[2:0], isar[2:0]};
				isar_we = 1'b1;
			end
		`OP_LISL: begin
				do_instr_last();
				isar_d = {isar[5:3], opcode[2:0]};
				isar_we = 1'b1;
			end
		`OP_LIS: begin
				do_instr_last();
				acc_write();
				lbus_sel = LBUS_CONST_F;
				rbus_sel = RBUS_INST;
				alu_op = `ALU_AND;
			end
		`OP_BT: begin
				case(instr)
				0: begin
					instr_romc(5'h1c);
				end
				1: begin
					if(opcode[2:0] & status[2:0]) instr_romc(5'h01);
					else begin
						instr_romc(5'h03);
						op_long = 1'b0;
					end
					// instr_romc((opcode[2:0] & status[2:0]) ? 5'd1 : 5'd3);
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_AM,`OP_AMD,`OP_CM: begin
				case(instr)
				0: begin
					instr_romc(5'h02);
					acc_read();
					if(opcode !=`OP_CM) acc_write();
					db_read();
					
					case(opcode)
					`OP_AM: alu_op = `ALU_ADD;
					`OP_AMD: alu_op = `ALU_ADD_BCD;
					`OP_CM: alu_op = `ALU_CMP;
					endcase
					
					alu_stat = 4'b1111;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end 
		`OP_NM,`OP_OM,`OP_XM: begin
				case(instr)
				0: begin
					instr_romc(5'h02);
					acc_read();
					acc_write();
					db_read();
					
					case(opcode)
					`OP_NM: alu_op = `ALU_AND;
					`OP_OM: alu_op = `ALU_OR;
					`OP_XM: alu_op = `ALU_XOR;
					endcase
					
					alu_stat = 4'b0101;
					new_stat = 4'b0000;

				end
				1: begin
					do_instr_last();
				end
				endcase
			end 
		`OP_ADC: begin
				case(instr)
				0: begin
					instr_romc(5'h0A);
					acc_read();
					db_write();
					alu_op = `ALU_L;
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_BR7: begin
				case(instr)
				0: begin
					//instr_romc(isar[2:0] == 3'd7 ? 5'h03 : 5'h01);
					if(isar[2:0] == 3'd7) begin
						instr_romc(5'h03);
						op_long = 1'b0;
					end else instr_romc(5'h01);
				end
				1: begin
					do_instr_last();
				end
				endcase
			end
		`OP_BF: begin
				case(instr)
				0: begin
					instr_romc(5'h1c);
				end
				1: begin
					if(opcode[3:0] & status[3:0]) begin
						instr_romc(5'h03);
						op_long = 1'b0;
					end else instr_romc(5'h01);
					//instr_romc((opcode[3:0] & status[3:0]) ? 5'h03 : 5'h01);
				end
				2: begin
					do_instr_last();
				end
				endcase
			end
		`OP_INS01: begin
				case(instr)
				0: begin
					instr_romc(5'h1c);
					db_write();
					acc_write();
					io_read(opcode[0]);
					alu_op = `ALU_R;
					alu_stat = 4'b0101;
					new_stat = 4'b0000;
				end
				1: do_instr_last();
				endcase
			end
		`OP_INS: begin
				case(instr)
				0: begin
					instr_romc(5'h1c);
					db_write();	// User Guide 5-24
					
					op_long = 1'b1;
					db_write();
					rbus_sel = RBUS_INST;
					lbus_sel = LBUS_CONST_F;
					alu_op = `ALU_AND;						
				end
				1: begin
					instr_romc(5'h1b);
					db_read();
					acc_write();
					alu_op = `ALU_R;
					
					alu_stat = 4'b0101;
					new_stat = 4'b0000;
				end
				2: do_instr_last();
				endcase
			end
		`OP_OUTS01: begin
				case(instr)
				0: begin
					instr_romc(5'h1c);
					db_write();
					acc_read();
					io_write(opcode[0]);
				end
				1: do_instr_last();
				endcase
			end
		`OP_OUTS: begin
				disallow_irq = 1'b1;

				case(instr)
				0: begin
					instr_romc(5'h1c);
					op_long = 1'b1;

					db_write();
					rbus_sel = RBUS_INST;
					lbus_sel = LBUS_CONST_F;
					alu_op = `ALU_AND;
				end
				1: begin
					instr_romc(5'h1a);
					db_write();
					acc_read();
					alu_op = `ALU_L;
				end
				2: do_instr_last();
				endcase
			end
		`OP_AS, `OP_ASD: begin
				do_instr_last();
		
				acc_write();
				scr_read(op_isar(opcode));
				
				casex(opcode)
				`OP_AS: alu_op = `ALU_ADD;
				`OP_ASD: alu_op = `ALU_ADD_BCD;
				endcase

				alu_stat = 4'b1111;
			end
		`OP_XS,`OP_NS: begin
				do_instr_last();
				
				acc_write();
				scr_read(op_isar(opcode));
				
				casex(opcode)
				`OP_XS: alu_op = `ALU_XOR;
				`OP_NS: alu_op = `ALU_AND;
				endcase

				alu_stat = 4'b0101;
				new_stat = 4'b0000;
			end
			endcase
		end
	end
  
	f8_3850_alu i_alu(
		.op(alu_op),
		.left(lbus),
		.right(rbus),
		.c_in(c),
		.result(result),
		.c(alu_c),
		.z(alu_z),
		.ov(alu_ov),
		.s(alu_s)
		);
	
endmodule