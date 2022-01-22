module sram_sdi_test(
	input clk,
	input reset,
	output reg [1:0] status,
	
	output sck,
	output reg cs,
	inout [1:0] d);
	
	localparam [1:0] STAT_INIT=2'b00, STAT_WR=2'b01, STAT_RD=2'b10, STAT_FAIL=2'b11;
	
	localparam [2:0] ST_INIT_SDI=3'd0, ST_WR_BANK0=3'd1, ST_RD_BANK0=3'd2, ST_WR_BANK1=3'd3, ST_RD_BANK1=3'd4, ST_FAIL=3'd5;
	
	reg [15:0] crc_write;
	wire [15:0] crc_out;
	reg crc_en, crc_rst;
	
	reg [20:0] ticks;
	reg [2:0] state;
	
	reg do_read;
	
	reg [7:0] sr;
	reg sr_in_rdy, sr_in_en, sr_in_en_d;
	reg [1:0] sr_in_cnt;
	
	wire [1:0] din;
	reg sck_en, sck_en_d;
	
	wire [7:0] lfsr_out;
	reg lfsr_ld;
	reg [7:0] count;
	
	always @(*) begin
		case(state)
		ST_INIT_SDI: status = STAT_INIT;
		ST_WR_BANK0, ST_WR_BANK1: status = STAT_WR;
		ST_RD_BANK0, ST_RD_BANK1: status = STAT_RD;
		default: status = STAT_FAIL;
		endcase
	end
	
	reg mode_sdi, en_out;
	assign d[0] = en_out ? (mode_sdi ? sr[6] : sr[7]) : 1'bz;
	assign d[1] = (en_out && mode_sdi) ? sr[7] : 1'bz;
	
`ifdef SIMULATION
	reg sck_q0, sck_q1, sck_q1_d;
	always @(posedge clk) begin
		sck_q0 <= 1'b0;
		sck_q1 <= sck_en;
	end
	
	always @(negedge clk) begin
		sck_q1_d <= sck_q1;
	end
	assign sck = clk ? sck_q0 : sck_q1_d;
	
`else
	ODDRXE i_oddr_sck(.D0(1'd0), .D1(sck_en), .SCLK(clk), .RST(reset), .Q(sck));
`endif

	lfsr8 i_lfsr(.clk(clk), .en(1'b1), .ld(lfsr_ld), .in(8'hfe), .out(lfsr_out));
	crc i_crc(.clk(clk), .crc_en(crc_en), .crc_out(crc_out), .rst(crc_rst), 
		.data_in(do_read ? d : sr[7:6]));
`ifndef TEST_BYTES
`define TEST_BYTES	 21'h40000
`endif

//`define TEST_BYTES 21'h40000
`define TEST_LFSR

	always @(posedge clk) begin
		if(reset) begin
			state <= ST_INIT_SDI;			cs <= 1'b1;
			sck_en <= 1'b0;
			en_out <= 1'b0;
			mode_sdi <= 1'b0;
			ticks <= 21'd0;
			crc_en <= 1'b0;
			do_read <= 1'b0;
		end else begin
			ticks <= ticks + 1;
			sck_en_d <= sck_en;
			lfsr_ld <= 1'b0;
			crc_rst <= 1'b0; 
			if(state == ST_INIT_SDI) begin
				en_out <= 1'b1;
				if(sck_en_d) sr <= {sr[6:0], 1'b0};
				
				case(ticks)
				21'd0: begin
					lfsr_ld <= 1'b1;
					cs <= 1'b0;
					sr <= 8'h3b;
					sck_en <= 1'b1;
					en_out <= 1'b1;
				end
				21'd8: sck_en <= 1'b0;
				21'd10: begin
					cs <= 1'b1;
					state <= ST_WR_BANK0;
					ticks <= 21'd0;
					en_out <= 1'b0;
					mode_sdi <= 1'b1;
				end
				endcase
			end else if(state == ST_FAIL) begin
			end else if(do_read) begin
				case(ticks)
					
				21'd21: crc_en <= 1'b1;
				//21'd1048596: begin
				//21'd52: begin
				(20 + 4 * `TEST_BYTES): begin
					crc_en <= 1'b0;
				end
				
				//21'd1048597: begin
				//21'd53: begin
				(21 + 4 * `TEST_BYTES): begin
					sck_en <= 1'b0;
				end
				//21'd1048598: begin
				//21'd54: begin
				(22 + 4 * `TEST_BYTES): begin
					cs <= 1'b1;
					state <= (crc_out != crc_write) ? ST_FAIL :
							  (state == ST_RD_BANK0) ? ST_WR_BANK1 : ST_WR_BANK0;
					do_read <= 1'b0;
					ticks <= 21'd0;
				end
				endcase
			end else begin
				if(sck_en_d) sr <= {sr[5:0], 2'b0};
				
				case(ticks)
				21'd0: begin
					cs <= 1'b0;
					en_out <= 1'b1;
					sck_en <= 1'b1;
					crc_rst <= 1'b1;
				end
				21'd1:	sr <= (state == ST_RD_BANK0 || state == ST_RD_BANK1) ? 8'h03 : 8'h02; //read or write
				21'd5: sr <= (state == ST_RD_BANK0 || state == ST_WR_BANK0) ? 8'h00 : 8'h04;
				21'd9, 20'd13: sr <= 8'h00;	//unnecessary but whatever
				21'd17: begin
					if(state == ST_RD_BANK0 || state == ST_RD_BANK1) begin
						do_read <= 1'b1;
						en_out <= 1'b0;
					end else begin
`ifdef TEST_LFSR
						sr <= lfsr_out;
`else
						sr <= 8'h01;
						count <= 8'h02;
`endif
						crc_en <= 1'b1;
					end
				end
				//21'd1048592: begin	// 18 + 256 * 1024 * 4 - 2
				//48: begin
				(16 + 4 * `TEST_BYTES): begin
					sck_en <= 1'b0;
					crc_en <= 1'b0;
				end
				//21'd1048593: begin
				//49: begin
				(17 + 4 * `TEST_BYTES): begin
				end
				//21'd1048594: begin
				//50: begin
				(18 + 4 * `TEST_BYTES):begin
					cs <= 1'b1;
					en_out <= 1'b0;
					crc_write <= crc_out;
					state <= (state == ST_WR_BANK0) ? ST_RD_BANK0 : ST_RD_BANK1;
					ticks <= 21'd0;
				end
				default: begin
					if(ticks[1:0] == 2'b01) begin
`ifdef TEST_LFSR
					sr <= lfsr_out;
`else
					sr <= count;
					count <= count + 1;
`endif
					end
				end
				endcase
			end
		end
	end
endmodule
			
	