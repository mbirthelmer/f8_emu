`timescale 1ns/1ps

module tb_sram_sdi_test;

	reg clk, rst;
	
	wire [1:0] sram_d;
	wire sram_sck_out;
	reg sram_sck;
	wire sram_cs;
	
	wire [1:0] status;
	
	sram_sdi_test i_sram_sdi_test(.clk(clk), .reset(rst), .status(status),
		.sck(sram_sck_out), .cs(sram_cs), .d(sram_d));
	
	reg [7:0] sram[524287:0];
	
	
	reg [19:0] sram_addr;
	
	reg sram_setup, sram_read, sram_write, sram_turnaround;
	reg [2:0] bitcnt;
	reg [1:0] bytecnt;
	reg [7:0] opcode, sr;
	reg [1:0] d_out;
	
	reg mode_sdi;
	
	assign sram_d = (sram_turnaround || sram_write || sram_setup) ? 2'bzz :
					mode_sdi ? d_out : {d_out[1], 1'bz};
	
	initial mode_sdi = 1'b0;
	wire last_cycle;
	
	assign last_cycle = mode_sdi ? (bitcnt == 3'd3) : (bitcnt == 3'd7);
	
	always #31.25 clk = ~clk;
		
	always #1 sram_sck = sram_sck_out;
		
	initial begin
		$dumpfile("sram_sdi_test.cvd");
		$dumpvars;
		clk = 1'b0;
		rst = 1'b1;
		
		#100;
		rst = 1'b0;
		
		wait(status == 2'b11 || status == 2'b01);
		wait(status == 2'b11 || status == 2'b10);
		wait(status == 2'b11 || status == 2'b01);
		wait(status == 2'b11 || status == 2'b10);
		wait(status == 2'b11 || status == 2'b01);
		
		#1000;
		
		$finish;
	end


	always @(negedge sram_cs) begin
		sram_setup <= 1'b1;
		sram_read <= 1'b0;
		sram_write <= 1'b0;
		sram_turnaround <= 1'b0;
		bitcnt <= 3'd0;
		bytecnt <= 2'd0;
	end
	
	always @(posedge sram_cs) begin
		if(opcode == 8'h3b) mode_sdi <= 1'b1;
		if(opcode == 8'hff) mode_sdi <= 1'b0;
	end
	
	always @(*) begin
		d_out = #36 sr[7:6];
	end
	
	always @(negedge sram_sck) begin
		if(sram_cs == 1'b0) begin
			bitcnt <= bitcnt + 1;

			if(sram_read) begin
				sr <= mode_sdi ? {sr[5:0], 2'b0} : {sr[6:0], 1'b0};
			end
			

			if(last_cycle) begin
				bitcnt <= 3'd0;
				bytecnt <= bytecnt + 1;
				
				if(sram_setup) begin
					if(bytecnt == 2'd0) begin
						opcode <= sr;
					end
					
					if(bytecnt == 2'd3) begin
						sram_setup <= 1'b0;
						if(opcode == 8'h03) begin
							sram_addr[18:0] <= sram_addr[18:0] + 1;
							sr <= sram[sram_addr];
							sram_read <= !mode_sdi;
							sram_turnaround <= mode_sdi;
						end else if(opcode == 8'h02) begin
							sram_write <= 1'b1;
						end
					end
				
					sram_addr <= {sram_addr[11:0], sr};
				end
				
				if(sram_write) begin
					sram_addr[18:0] <= sram_addr[18:0] + 1;
					sram[sram_addr] <= sr;
				end
				
				if(sram_turnaround || sram_read) begin
					sram_addr[18:0] <= sram_addr[18:0] + 1;
					sr <= sram[sram_addr];
				end
			end			
		end

	end
	
	
	always @(posedge sram_sck) begin
		if(sram_cs == 1'b0) begin
			if(sram_setup) begin
				sr <= mode_sdi ? {sr[5:0], sram_d} : {sr[6:0], sram_d[0]};
				

			end else if(sram_turnaround) begin
				if(last_cycle) begin
					sram_turnaround <= 1'b0;
					sram_read <= 1'b1;
				end
			end else if(sram_write) begin
				sr <= mode_sdi ? {sr[5:0], sram_d} : {sr[6:0], sram_d[0]};
			end
		end
	end
endmodule
				
					
					
					
			
		