module uart_if(
	output reg tx,
	input [7:0] txd,
	input txv,
	output reg txr,
	
	input rx,
	output reg [7:0] rxd,
	output reg rxv,
	
	output reg rx_error,
	
	input rst,
	input clk_96m,
	input clk_12m);
	
	reg [7:0] tx_sr;
	reg [1:0] tx_state;
	reg [2:0] tx_bits;
	
	localparam [1:0] TX_IDLE=0, TX_START=1, TX_DATA=2, TX_STOP=3;
	
	always @(posedge clk_12m) begin
		if(rst) begin
			tx_sr <= 8'h00;
			tx_state <= TX_IDLE;
			tx_bits <= 3'h0;
		end else begin
			if(tx_state == TX_IDLE && txv) begin
				tx_state <= TX_START;
				tx_sr <= txd;
			end else if(tx_state == TX_START) begin
				tx_state <= TX_DATA;
				tx_bits <= 3'd7;
			end else if(tx_state == TX_DATA) begin
				tx_state <= (tx_bits == 3'd0) ? TX_STOP : TX_DATA;
				tx_bits <=  tx_bits - 1;
				tx_sr <= {1'b0, tx_sr[7:1]};
			end else if(tx_state == TX_STOP) begin
				tx_state <= TX_IDLE;
			end
		end
	end
	
	always @(*) begin
		txr = (tx_state == TX_IDLE);
		case(tx_state)
			TX_IDLE, TX_STOP: tx = 1'b1;
			TX_START: tx = 1'b0;
			TX_DATA: tx = tx_sr[0];
		endcase
	end
	
	reg [2:0] rx_div;
	reg [3:0] rx_state;
	reg [7:0] rx_sr;
	reg [2:0] rx_bits;
	reg [2:0] rx_vote;
	reg rx_result, rxv_96m, rxv_ack;
	
	reg [1:0] rx_sync;
	localparam [1:0] RX_IDLE=0, RX_START=1, RX_DATA=2, RX_STOP=3, RX_BREAK=4, RX_V_SYNC=5;
	
	always @(*) begin
		case(rx_vote)
		3'b000, 3'b001, 3'b010, 3'b100: rx_result = 0;
		3'b011, 3'b101, 3'b110, 3'b111: rx_result = 1;
		endcase
	end
	
	always @(posedge clk_12m) begin
		rxv <= rxv_96m;
		rxv_ack <= rxv_96m;
	end
	
	always @(posedge clk_96m) begin
		if(rst) begin
			rx_div <= 3'd0;
			rx_sr <= 8'h0;
			rx_state <= RX_IDLE;
			rx_bits <= 3'd0;
			
			rx_sync <= 2'h0;
		end else begin
			rx_sync <= {rx_sync[0], rx};
			rx_div <= (rx_state == RX_IDLE) ? 3'd0 : (rx_div + 1);
			rxv_96m <= 1'b0;
			
			if(rx_div == 3) rx_vote[0] <= rx_sync[1];
			if(rx_div == 4) rx_vote[1] <= rx_sync[1];
			if(rx_div == 5) rx_vote[2] <= rx_sync[1];
			
			if(rx_state == RX_IDLE) begin
				if(~rx_sync[1])
					rx_state <= RX_START;
			end else if(rx_state == RX_START && rx_div == 7) begin
				if(rx_result != 0) begin
					rx_state <= RX_IDLE;
					rx_error <= 1'b1;
				end else begin
					rx_state <= RX_DATA;
					rx_bits <= 3'd7;
				end
			end else if(rx_state == RX_DATA && rx_div == 7) begin
				rx_sr <= {rx_result, rx_sr[6:0]};
				rx_bits <= rx_bits - 1;
				rx_state <= (rx_bits == 0) ? RX_STOP : RX_DATA;
			end else if(rx_state == RX_STOP && rx_div == 7) begin
				rx_state <= RX_IDLE;
				
				if(rx_result != 1'b1) begin
					if(rx_sr == 8'h00) rx_state <= RX_BREAK;
					else begin
						rx_state <= RX_IDLE;
						rx_error <= 1'b1;
					end
				end else begin
					rx_state <= rx_error ? RX_IDLE : RX_V_SYNC;
					rxv_96m <= ~rx_error;
				end
			end else if(rx_state == RX_BREAK && rx_div == 7) begin
				if(rx_result != 1'b0) begin
					rx_error <= 1'b0;
					rx_state <= RX_IDLE;
				end
			end else if(rx_state == RX_V_SYNC && rxv_ack) begin
				rx_state <= RX_IDLE;
				rxv_96m <= 1'b0;
			end
		end
	end
endmodule
			