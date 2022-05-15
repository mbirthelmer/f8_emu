module devboard(
	input clk_12m_in,
	input rst_n,
	
	output flash_cs,
	
	output sram_sck,
	output sram_cs,
	inout [1:0] sram_d,
	output sram_fail,
	
	input [3:0] cfg_sw,
	output [7:0] led,
	
	input uart_rx,
	output uart_tx,
	
	input osc,
	output xtly,
		
	inout [7:0] io0,
	inout [7:0] io1,
	inout [7:0] db,
	
	output [7:0] emu_db,
	output [4:0] emu_romc,
	output emu_extra,
	//output emu_db_t,
	output reg cmp_err,
	
	inout [4:0] romc,

	inout extres_n,
	input intreq_n,
	inout icb_n,
	
	inout ph,
	inout write);
	
	wire [7:0] db_out, io0_out, io1_out;
	wire db_t;
	
	wire intreq_n_sync, extres_n_sync;
	wire [7:0] io0_in_sync, io1_in_sync;
	
	wire clk_20m, clk_16m, clk_96m, clk_12m, pll_lock;
	
	wire rst;
	assign rst = ~pll_lock;
	
	//assign db = db_t ? 8'hz : db_out;
	
	genvar i;
	
	for(i=0; i<8; i=i+1) begin
		assign io0[i] = io0_out[i] ? 1'bz : 1'b0;
		assign io1[i] = io1_out[i] ? 1'bz : 1'b0;
		assign db[i] = (db_t || db_out[i]) ? 1'bz : 1'b0;
	end
	
	assign uart_tx = uart_rx;
	
	in_pll i_pll(.CLKI(clk_12m_in), .CLKI2(osc), .SEL(cfg_sw[0]), .CLKOP(clk_12m), .CLKOS(clk_96m), .CLKOS2(clk_20m), .CLKOS3(clk_16m), .LOCK(pll_lock));
	
	wire emu_ph;
	assign xtly = emu_ph;
	
	//assign clk_2m = clk_div[2];
 
//`define IOTEST
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
	
	assign write = cfg_sw[1] ? 1'bz : (ticks[1:0] == 2'b11);
	
	assign romc = cfg_sw[1] ? {5{1'bz}} : ticks[15:11];
	
	assign led = ~{ticks[15:11], sram_test_status, pll_lock}; 
	
	assign icb_n = cfg_sw[1] ? 1'bz : (pll_lock & extres_n & intreq_n);
	
	//sram IS62WVS5128FALL-16NLI
	sram_sdi_test i_sram(.clk(clk_16m), .reset(~pll_lock), .status(sram_test_status),
		.sck(sram_sck), .cs(sram_cs), .d(sram_d));
		
	assign sram_fail = (sram_test_status == 2'b11);
	
`else

	assign extres_n = rst_n ? 1'bz : 1'b0;

	wire [7:0] emu_io0_out, emu_io1_out;
	wire emu_db_t, emu_write, emu_clk;
	wire cmp_io0_err, cmp_io1_err, cmp_db_err, cmp_romc_err, cmp_icb_err;
	
	sync i_res_sync(.clk(emu_ph), .rst(rst), .d(extres_n), .q(extres_n_sync));
	sync i_int_sync(.clk(emu_ph), .rst(rst), .d(intreq_n), .q(intreq_n_sync));
	//assign intreq_n_sync = intreq_n;
	//assign exters_n_sync = extres_n;
	
	for(i = 0; i < 8; i=i+1) begin
		sync i_io0_sync(.clk(emu_ph), .rst(rst), .d(io0[i]), .q(io0_in_sync[i]));
		sync i_io1_sync(.clk(emu_ph), .rst(rst), .d(io1[i]), .q(io1_in_sync[i]));
	end
	
	//assign io0_in_sync = io0;
	//assign io1_in_sync = io1;
	
	wire cmp_mode;
	
	assign cmp_mode = !cfg_sw[1];
	
	//wire [4:0] emu_romc;
	
	assign cmp_io0_err = |(~emu_io0_out & io0_in_sync);
	assign cmp_io1_err = |(~emu_io1_out & io1_in_sync);
	assign cmp_db_err = !emu_db_t && (db_out != db);
	assign cmp_romc_err = (emu_romc != romc);
	assign cmp_icb_err = (emu_icb_n != icb_n);
	
	reg [7:0] err_bits;
	assign led = ~err_bits;
	
	always @(posedge ph) begin
		if(!extres_n_sync) begin 
			cmp_err <= 1'b0;
		end else if(write && cmp_mode) begin
			cmp_err <= (cmp_io0_err || cmp_io1_err || cmp_db_err || cmp_romc_err);
		end 
	end
	
	assign romc = cmp_mode ? 5'bzzzzz : emu_romc;
	assign db_t = cmp_mode | emu_db_t;
	assign io0_out = cmp_mode ? 8'hff : emu_io0_out;
	assign io1_out = cmp_mode ? 8'hff : emu_io1_out;
	assign write = cmp_mode ? 1'bz : emu_write;//	assign emu_clk = cmp_mode ? ph : clk_2m;
	assign ph = cmp_mode ? 1'bz : emu_ph;
	assign icb_n = cmp_mode ? 1'bz : emu_icb_n;
	
	assign emu_db = db_out;
	assign emu_extra = ~emu_db_t;
	
	
	
	f8_3850 i_f8(
		.romc(emu_romc),
		.db_in(db),
		.db_out(db_out),
		.db_t(emu_db_t),
		.io0_in(io0_in_sync),
		.io0_out(emu_io0_out),
		.io1_in(io1_in_sync),
		.io1_out(emu_io1_out),
		.write(emu_write),
		.clk_phi(emu_ph),
		.int_rst_n(pll_lock),
		.clk_20m(clk_20m),
		.ext_res_n(extres_n_sync),
		.int_req_n(intreq_n_sync),
		.icb_n(emu_icb_n),
		.cmp_mode(1'b0),
		.cmp_write_in(write));
`endif
endmodule