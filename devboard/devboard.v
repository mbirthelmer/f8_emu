module devboard(
	input clk_12m_in,
	input rst_n,
	
	output flash_cs,
	
	output sram_sck,
	output sram_cs,
	inout [1:0] sram_d,
	
	input [3:0] cfg_sw,
	output [7:0] led,
	
	input uart_rx,
	output uart_tx,
	
	input osc,
	output xtly,
		
	inout [7:0] io0,
	inout [7:0] io1,
	inout [7:0] db,
	
	output [4:0] romc,

	input extres_n,
	input intreq_n,
	output icb_n,
	
	output ph,
	output write);
	
	wire [7:0] db_out, io0_out, io1_out;
	wire db_t;
	
	wire clk_2m, clk_16m, clk_96m, clk_12m, pll_lock;
	
	//assign db = db_t ? 8'hz : db_out;
	
	genvar i;
	
	for(i=0; i<8; i=i+1) begin
		assign io0[i] = io0_out[i] ? 1'b0 : 1'bz;
		assign io1[i] = io1_out[i] ? 1'b0 : 1'bz;
		assign db[i] = (db_t || db_out[i]) ? 1'bz : 1'b0;
	end
	
	assign uart_tx = uart_rx;
	
	in_pll i_pll(.RST(~rst_n), .CLKI(clk_12m_in), .CLKI2(osc), .SEL(cfg_sw[0]), .CLKOP(clk_12m), .CLKOS(clk_96m), .CLKOS2(clk_2m), .CLKOS3(clk_16m), .LOCK(pll_lock));
 
`define IOTEST
`ifdef IOTEST
	reg [15:0] ticks;
	wire [1:0] sram_test_status;
	
	always @(posedge clk_2m) begin
		ticks <= ticks + 1;
	end 
	
	assign io0_out = cfg_sw[1] ? 8'hff : ticks[15:8];
	assign io1_out =  cfg_sw[1] ? 8'hff : ticks[15:8];
	assign db_out = ticks[15:8];
	assign db_t = cfg_sw[1];
	assign ph = cfg_sw[1] ? 1'bz : clk_2m;
	assign xtly = clk_2m;
	
	assign write = cfg_sw[1] ? 1'bz : (ticks[1:0] == 2'b11);
	
	assign romc = cfg_sw[1] ? 1'bz : ticks[15:11];
	
	assign led = ~{ticks[15:11], sram_test_status, pll_lock}; 
	
	assign ext_res_n = cfg_sw[1] ? pll_lock : 1'bz;
	
	sram_sdi_test i_sram(.clk(clk_16m), .reset(~pll_lock), .status(sram_test_status),
		.sck(sram_sck), .cs(sram_cs), .d(sram_d));
		
	
`else
	f8_3850 i_f8(
		.romc(romc),
		.db_in(db),
		.db_out(db_out),
		.db_t(db_t),
		.io0_in(io0),
		.io0_out(io0_out),
		.io1_in(io1),
		.io1_out(io1_out),
		.write(write),
		.clk_phi(ph),
		.clk(clk_2m),
		.ext_res_n(extres_n),
		.int_req_n(intreq_n),
		.icb_n(icb_n));
`endif
endmodule