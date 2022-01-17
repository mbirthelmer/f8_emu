`timescale 1ns/1ps
`include "f8_ops.vh"

module tb_f8_3850;

	reg clk, rst_n, irq_n;
	wire phi, write, icb_n, db_t;

	wire [4:0] romc;
	reg [7:0] db_in, io0_in, io1_in;
	wire [7:0] db_out, io0_out, io1_out;

	reg [15:0] dc0, dc1, pc0, pc1;

	f8_3850 i_f8(
		.romc(romc),
		.db_in(db_in),
		.db_out(db_out),
		.db_t(db_t),
		.write(write),
		.clk_phi(phi),
		.clk(clk),
		.io0_in(io0_in),
		.io0_out(io0_out),
		.io1_in(io1_in),
		.io1_out(io1_out),
		.ext_res_n(rst_n),
		.int_req_n(irq_n),
		.icb_n(icb_n)
	);

	integer i;

	always #250 clk=~clk;

	initial begin
		$dumpfile("f8.vcd");
		$dumpvars;

		clk = 1'b0;
		rst_n = 1'b0;

		#900;
		rst_n = 1'b1;

		wait(pc0 == 16'h07ff);

		@(posedge write);

		$finish;

	end
	
	
	localparam [15:0] ROM_START=16'h0, ROM_END=16'h2fff, RAM_START=16'h8000, RAM_END=16'h81ff;

	reg [7:0] rom[ROM_START:ROM_END];
	initial $readmemh("f8_test.mem", rom);
	reg [7:0] ram[RAM_START:RAM_END];

	wire pc0_in_rom;
	wire dc0_in_ram;

	assign pc0_in_rom = (pc0 >= ROM_START && pc0 <= ROM_END );
	assign dc0_in_ram = (dc0 >= RAM_START && dc0 <= RAM_END);

	reg [7:0] db_mem, db;
	reg db_mem_t;

	always @(*) begin
		case({db_t, db_mem_t})
		2'b10: db = db_mem;
		2'b01: db = db_out;
		2'b00: $error("Bus contention!");
		default: db = 8'hff;
		endcase
	end

	always @(negedge write) begin
		#200;
		db_mem_t = 1'b1;
		#1000;

		case(romc)
		5'h0, 5'h3: begin
			if(pc0_in_rom) db_mem = rom[pc0];
			db_mem_t = !pc0_in_rom;
			pc0 = pc0 + 1;
		end
		5'h1: begin
			if(pc0_in_rom) db_mem = rom[pc0];
			db_mem_t = !pc0_in_rom;
			pc0 = pc0 + $signed(db);
		end
		5'h2: begin
			if (dc0_in_ram) db_mem = ram[dc0];
			db_mem_t = !dc0_in_ram;
			dc0 = dc0 + 1;
		end
		5'h4: pc1 = pc0;
		5'h5: begin
			if(dc0_in_ram) ram[dc0] = db;
			dc0 = dc0 + 1;
		end
		5'h6: begin
			db_mem = dc0[15:8];
			db_mem_t = 1'b0;
		end
		5'h7: begin
			db_mem = pc1[15:8];
			db_mem_t = 1'b0;
		end
		5'h8: begin
			pc1 = pc0;
			pc0 = {db, db};
		end
		5'h9: begin
			db_mem = dc0[7:0];
			db_mem_t = 1'b0;
		end
		5'ha: dc0 = dc0 + $signed(db);
		5'hb: begin
			if(pc1 >= ROM_START && pc1 <= ROM_END) begin
				db_mem = pc1[7:0];
				db_mem_t = 1'b0;
			end
		end
		5'hc: begin
			if(pc0_in_rom) db_mem = rom[pc0];
			db_mem_t = !pc0_in_rom;
			pc0[7:0] = db;
		end
		5'hd: pc1 = pc0 + 1;
		5'he: begin
			if(pc0_in_rom) db_mem = rom[pc0];
			db_mem_t = !pc0_in_rom;
			dc0[7:0] = db;
		end
		5'hf: pc0[7:0] = db;
		5'h10: begin end
		5'h11: begin
			if(pc0_in_rom) db_mem = rom[pc0];
			db_mem_t = !pc0_in_rom;
			dc0[15:8] <= db;
		end
		5'h12: begin
			pc1 = pc0;
			pc0[7:0] = db;
		end
		5'h13: begin end
		5'h14: pc0[15:8] = db;
		5'h15: pc1[15:8] = db;
		5'h16: dc0[15:8] = db;
		5'h17: pc0[7:0] = db;
		5'h18: pc1[7:0] = db;
		5'h19: dc0[7:0] = db;
		5'h1a: begin end
		5'h1b: begin end
		5'h1c: begin end
		5'h1d: begin
			dc0 <= dc1;
			dc1 <= dc0;
		end
		5'h1e: if(pc0_in_rom) begin
			db_mem = pc0[7:0];
			db_mem_t = 1'b0;
		end
		5'h1f: if(pc0_in_rom) begin
			db_mem = pc0[15:8];
			db_mem_t = 1'b0;
		end
		endcase



	end

endmodule
