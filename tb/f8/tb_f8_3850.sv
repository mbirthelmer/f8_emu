`timescale 1ns/1ps
`include "f8_ops.vh"

module tb_f8_3850;

	reg clk_20m, int_rst_n, rst_n, irq_n;
	wire phi, write, icb_n, db_t;

	wire [4:0] romc;
	reg [7:0] db, io0_in, io1_in;
	wire [7:0] db_out, io0_out, io1_out;

	reg [15:0] dc0, dc1, pc0, pc1;

	f8_3850 i_f8(
		.romc(romc),
		.db_in(db),
		.db_out(db_out),
		.db_t(db_t),
		.write(write),
		.clk_phi(phi),
		.clk_20m(clk_20m),
		.int_rst_n(int_rst_n),
		.io0_in(io0_in),
		.io0_out(io0_out),
		.io1_in(io1_in),
		.io1_out(io1_out),
		.ext_res_n(rst_n),
		.int_req_n(irq_n),
		.icb_n(icb_n),

		.cmp_mode(1'b0),
		.cmp_write_in(1'b0)
	);

	integer i;

	always #25 clk_20m=~clk_20m;
	
	initial begin
		$dumpfile("f8.vcd");
		$dumpvars;

		clk_20m = 1'b0;
		rst_n = 1'b0;
		int_rst_n = 1'b0;

		#325;

		int_rst_n = 1'b1;

		#10025;
		rst_n = 1'b1;
		irq_n = 1'b0;

		io0_in = 8'h77;

		@(posedge icb_n);

		irq_n = 1'b1;

		wait(pc0 == 16'h07ff);

		repeat (10) @(posedge write);

		$finish;

	end


	localparam [15:0] ROM_START=16'h0, ROM_END=16'h2fff, RAM_START=16'h8000, RAM_END=16'h81ff;

	reg [7:0] rom[ROM_START:ROM_END];
	initial $readmemh("f8_test.mem", rom);
	reg [7:0] ram[RAM_START:RAM_END];

	wire pc0_in_rom;
	wire dc0_in_ram;
	wire dc0_in_rom;

	assign pc0_in_rom = (pc0 >= ROM_START && pc0 <= ROM_END );
	assign pc1_in_rom = (pc1 >= ROM_START && pc1 <= ROM_END );
	assign dc0_in_ram = (dc0 >= RAM_START && dc0 <= RAM_END);
	assign dc0_in_rom = (dc0 >= ROM_START && dc0 <= ROM_END );

	reg [7:0] db_mem;
	reg db_mem_t;

	//reg [7:0] io[0:3], db_buf;
	reg [7:0] isr_l, isr_h, db_buf;

	always @(*) begin
		case({db_t, db_mem_t})
		2'b10: db = db_mem;
		2'b01: db = db_out;
		2'b00: $error("Bus contention!");
		default: db = 8'hff;
		endcase
	end

	wire signed [15:0] db_rel_offset;
	assign db_rel_offset = $signed(db);

`define TD7 650 //td3 -> td7


	always @(negedge write) begin
		#200;	//td8
		db_buf = db;
		db_mem_t = #200 1'b1;

		#350;  // td3
		case(romc)
		5'h0, 5'h1, 5'h3, 5'hc, 5'he, 5'h11: begin
			if(pc0_in_rom) db_mem = rom[pc0];
			db_mem_t = #`TD7 !pc0_in_rom;
		end
		5'h2: begin
			if (dc0_in_ram) db_mem = ram[dc0];
			else if(dc0_in_rom) db_mem = rom[dc0];
			db_mem_t = #`TD7 !(dc0_in_ram || dc0_in_rom);
		end
		5'h6: begin
			db_mem = dc0[15:8];
			db_mem_t = #`TD7 1'b0;
		end
		5'h7: begin
			db_mem = pc1[15:8];
			db_mem_t = #`TD7 1'b0;
		end
		5'h9: begin
			db_mem = dc0[7:0];
			db_mem_t = #`TD7 1'b0;
		end
		5'hb: begin
			if(pc1_in_rom) db_mem = pc1[7:0];
			db_mem_t = #`TD7 !pc1_in_rom;
		end
		5'h0f: begin
			db_mem_t = #`TD7 1'b0;
			db_mem = isr_l;
		end
		5'h13: begin
			db_mem_t = #`TD7 1'b0;
			db_mem = isr_h;
		end
		5'h1b: begin
			if(db_buf[7:2] == 6'h03) begin
				db_mem = db_buf[0] ? isr_l : isr_h;
				db_mem_t = #`TD7 1'b0;
			end
		end
		5'h1e: if(pc0_in_rom) begin
			db_mem = pc0[7:0];
			db_mem_t = #`TD7 1'b0;
		end
		5'h1f: if(pc0_in_rom) begin
			db_mem = pc0[15:8];
			db_mem_t = #`TD7 1'b0;
		end
		default: begin
			db_mem_t = #`TD7 1'b1;
		end
		endcase
	end



	always @(negedge write) begin
		case(romc)
		5'h0, 5'h3: pc0 = pc0 + 1;
		5'h1: pc0 = pc0 + db_rel_offset;
		5'h2: dc0 = dc0 + 1;
		5'h4: pc0 = pc1;
		5'h5: if(dc0_in_ram) ram[dc0] = #1900 db;
		5'h8: begin
			pc1 = pc0;
			pc0 = {db, db};
		end
		5'ha: dc0 = dc0 + db_rel_offset;
		5'hc, 5'h17: pc0[7:0] = db;
		5'hd: pc1 = pc0 + 1;
		5'he, 5'h19: dc0[7:0] = db;
		5'h13, 5'h14: pc0[15:8] = db;
		5'h0f, 5'h12: begin
			pc1 = pc0;
			pc0[7:0] = db;
		end
		5'h15: pc1[15:8] = db;
		5'h11, 5'h16: dc0[15:8] = db;
		5'h18: pc1[7:0] = db;
		5'h1a: if(db_buf[7:2] == 6'h03) begin
			if(db_buf[0]) isr_l = db;
			else isr_h = db;
		end
		5'h1d: {dc0, dc1} = {dc1, dc0};
		endcase


	end

endmodule
