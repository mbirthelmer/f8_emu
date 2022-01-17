module devboard_clk(
	input osc,
	output xtly);
	
	reg [1:0] div;
	reg xtly_drv;
	
	assign xtly = xtly_drv ? 1'b0 : 1'bz;
	
	always @(posedge osc) begin
		div <= div + 1;
		if(div == 2'd2) begin
			div <= 2'd0;
			xtly_drv <= ~xtly_drv;
		end
	end
endmodule