/* Instruction-Fetch */
module Ifetch(input clk,
	input set_rip,
	input[63:0] new_rip,

	output ic_enable,
	output[63:0] iaddr,
	input[511:0] idata,
	input ic_done,

	output[0:15*8-1] decode_bytes,
	output[63:0] decode_rip,
	input[7:0] bytes_decoded,

	output if_dc
);

	/* verilator lint_off WIDTH */
	logic initialized;

	initial begin
		initialized = 0;
	end

	enum { fetch_idle, fetch_waiting, fetch_active, fetch_rst_waiting } fetch_state;
	logic[63:0] fetch_rip;
	logic[5:0] fetch_skip;
	logic[6:0] fetch_offset, decode_offset;

	logic[0:2*64*8-1] decode_buffer; // NOTE: buffer bits are left-to-right in increasing order

	logic send_fetch_req;

	always_comb begin
		if (fetch_state != fetch_idle) begin
			send_fetch_req = 0; // hack: in theory, we could try to send another request at this point
		end else if (initialized) begin
			send_fetch_req = (fetch_offset - decode_offset < 7'd32);
		end
	end

	always @ (posedge clk) begin
		if (set_rip) begin
			initialized <= 1;
			decode_rip <= new_rip;
			fetch_rip <= new_rip & ~63;
			fetch_skip <= new_rip[5:0];
			fetch_offset <= 0;

			decode_offset <= 0;
			decode_buffer <= 0;
			if (fetch_state != fetch_idle) begin
				if (ic_done)
					fetch_state <= fetch_idle;
				else
					fetch_state <= fetch_rst_waiting;
			end
		end else begin
			if (fetch_state == fetch_rst_waiting) begin
				if (ic_done)
					fetch_state <= fetch_idle;
			end else if (fetch_state == fetch_waiting) begin
				ic_enable <= 0;
				if (ic_done == 1) begin
					for (int i = {26'h0,fetch_skip}; i < 64; i += 1) begin
						decode_buffer[(fetch_offset+i-fetch_skip)*8+:8] <= idata[i*8+:8];
					end
					fetch_offset <= fetch_offset + (64 - fetch_skip);
					fetch_skip <= 0;
					iaddr <= 0;
					fetch_state <= fetch_idle;
					fetch_rip <= fetch_rip + 64;
				end
			end else if (send_fetch_req) begin // !fetch_waiting
				ic_enable <= 1;
				iaddr <= fetch_rip & ~63;
				fetch_state <= fetch_waiting;
			end

			decode_offset <= decode_offset + { bytes_decoded[6:0] };
			decode_rip <= decode_rip + {56'h0, bytes_decoded};
		end
	end

 	/* NOTE: buffer bits are left-to-right in increasing order */
	wire[0:(128+15)*8-1] decode_bytes_repeated = { decode_buffer, decode_buffer[0:15*8-1] };
	wire[0:15*8-1] decode_bytes = decode_bytes_repeated[decode_offset*8 +: 15*8];
	assign if_dc = (fetch_offset - decode_offset >= 7'd15);

endmodule

