module sram_sdi #(parameter ADDRBITS=17) (
	input clk,
	input reset,

	output ready,

	output sck,
	output reg cs,
	inout [1:0] d,

	input [ADDRBITS-1:0] start_addr,

	input en_burst,
	input write,

	input data_in_valid,
	output data_in_ready,
	input [31:0] data_in,


	input data_out_ready,
	output data_out_valid,
	output reg [31:0] data_out

	);

	localparam [2:0] ST_INIT_SDI=3'd0, ST_IDLE=3'd1, ST_SETUP=3'd2, ST_WRITE_WAIT=3'd3, ST_XFER=3'd4, ST_RESTART=3'd5, ST_READ_WAIT=3'd6, ST_FINISH=3'd7;


`ifdef SIMULATION
	reg sck_q0, sck_q1, sck_q1_d, sck_q;
	always @(posedge clk) begin
		sck_q <= 1'b0;
		sck_q1 <= sck_en;
	end
	
	always @(negedge clk) begin
		//sck_q1_d <= sck_q1;
		sck_q <= sck_q1;
	end
	assign sck = sck_q;
	//assign sck = clk ? sck_q0 : sck_q1_d;


	
`else
	ODDRXE i_oddr_sck(.D0(1'd0), .D1(sck_en), .SCLK(clk), .RST(reset), .Q(sck));
`endif

	reg [2:0] state;
	wire mode_sdi;

	assign mode_sdi = (state != ST_INIT_SDI);
	assign ready = (state == ST_IDLE);

	assign data_in_ready = (state == ST_WRITE_WAIT);
	assign data_out_valid = (state == ST_READ_WAIT);

	reg [5:0] ticks;
	reg sck_en, sck_en_d, en_out;

	assign d[0] = en_out ? (mode_sdi ? sr[30] : sr[31]) : 1'bz;
	assign d[1] = (en_out && mode_sdi) ? sr[31] : 1'bz;

	reg [31:0] sr;
	reg [ADDRBITS-1:0] addr;
	wire bank_boundary;
	assign bank_boundary = ~|addr[ADDRBITS-2:0];

	reg write_r;

	always @(posedge clk) begin
		if(reset) begin
			state <= ST_INIT_SDI;
			cs <= 1'b1;
			sck_en <= 1'b0;
			en_out <= 1'b0;
			ticks <= 6'd0;
		end else begin
			ticks <= ticks + 1;
			sck_en_d <= sck_en;

			if(sck_en_d)
				sr <= mode_sdi ? {sr[29:0], d} : {sr[30:0], d[1]};

			if(state == ST_INIT_SDI) begin
				case(ticks)
				0: begin
					cs <= 1'b0;
					sr <= 32'hff000000;
					sck_en <= 1'b1;
					en_out <= 1'b1;
				end
				8: sck_en <= 1'b0;
				10: cs <= 1'b1;
				12: begin
					cs <= 1'b0;
					sr <= 32'h3b000000;
					sck_en <= 1'b1;
					en_out <= 1'b1;
				end
				20: sck_en <= 1'b0;
				22: begin
					cs <= 1'b1;
					state <= ST_IDLE;
				end
				endcase
			end else if(state == ST_IDLE) begin
				if (en_burst) begin
					cs <= 1'b0;
					ticks <= 6'd0;
					state <= ST_SETUP;
					sr <= {(write ? 8'h02 : 8'h03), 24'b0 | (start_addr << 2)};
					sck_en <= 1'b1;
					en_out <= 1'b1;
					write_r <= write;
					addr <= start_addr;
				end
			end else if(state == ST_SETUP) begin
				case(ticks)
				15: begin
					if(write_r) begin
						sck_en <= 1'b0;
						state <= ST_WRITE_WAIT;
					end
				end
				16: en_out <= 1'b0;
				19: begin
					state <= ST_XFER;
					ticks <= 6'd0;
				end
				endcase
			end else if(state == ST_WRITE_WAIT) begin
				ticks <= 6'd0;
				if(!en_burst) begin
					state <= ST_FINISH;
				end else if(data_in_valid) begin
					sr <= data_in;
					sck_en <= 1'b1;
					state <= ST_XFER;
				end
			end else if(state == ST_READ_WAIT) begin
				ticks <= 6'd0;
				if(data_out_ready) begin
					data_out <= sr;
					ticks <= 6'd0;
					if(!en_burst) state <= ST_FINISH;
					else if(bank_boundary) state <= ST_RESTART;
					else begin
						state <= ST_XFER;
						sck_en <= 1'b1;
					end
				end
			end else if(state == ST_XFER) begin
				case(ticks)
				0: begin
					addr <= addr + 1;
				end
				15: sck_en <= 1'b0;					
				16: begin
					state <= write_r ? (bank_boundary ? ST_RESTART : ST_WRITE_WAIT) : ST_READ_WAIT;
					ticks <= 6'd0;
				end
				endcase
			end else if(state == ST_RESTART) begin
				case(ticks)
				1: cs <= 1'b1;
				3: begin
					cs <= 1'b0;
					ticks <= 6'd0;
					state <= ST_SETUP;
					sr <= {(write_r ? 8'h02 : 8'h03), 24'b0 | (addr << 2)};
					sck_en <= 1'b1;
					en_out <= 1'b1;
				end
				endcase
			end else if(state == ST_FINISH) begin
				cs <= 1'b1;
				state <= ST_IDLE;
			end
		end
	end
endmodule