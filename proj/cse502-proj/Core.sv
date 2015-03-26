module Core (
	input[63:0] entry
,	/* verilator lint_off UNDRIVEN */ /* verilator lint_off UNUSED */ Sysbus bus /* verilator lint_on UNUSED */ /* verilator lint_on UNDRIVEN */
);
	import "DPI-C" function int
	syscall_cse502(input int g1, input int o0, input int o1, input int o2, input int o3, input int o4, input int o5);

	enum { fetch_idle, fetch_waiting, fetch_active } fetch_state;
	logic [63:0] fetch_rip;
	logic [5:0] fetch_skip;
	logic [6:0] fetch_offset, decode_offset;
	logic [0:2*64*8-1] decode_buffer; // NOTE: buffer bits are left-to-right in increasing order

	logic send_fetch_req;
	always_comb begin
		if (fetch_state != fetch_idle) begin
			send_fetch_req = 0; // hack: in theory, we could try to send another request at this point
		end else if (bus.reqack) begin
			send_fetch_req = 0; // hack: still idle, but already got ack (in theory, we could try to send another request as early as this)
		end else begin
			send_fetch_req = (fetch_offset - decode_offset < 7'd32);
		end
	end

	assign bus.respack = bus.respcyc; // always able to accept response

	// logic to read responses from bus
	// and put them in the decode buffer
	always @(posedge bus.clk) begin
	
		// bus.reset?
		if (bus.reset) begin
			fetch_state <= fetch_idle;
			fetch_rip  <= entry & ~63;
			fetch_skip <= entry[5:0];
			fetch_offset <= 0;			
		end
		
		// !bus.reset
		else begin
		
			bus.reqcyc <= send_fetch_req;
			bus.req <= fetch_rip & ~63;
			bus.reqtag <= { bus.READ, bus.MEMORY, 8'b0 };

			// response ready?
			if (bus.respcyc) begin
				assert(!send_fetch_req) else $fatal;
				
				fetch_state <= fetch_active;
				fetch_rip <= fetch_rip + 8;
				if (fetch_skip > 0) begin
					fetch_skip <= fetch_skip - 8;
				end
				else begin
					decode_buffer[fetch_offset*8 +: 64] <= bus.resp;
					//$display("fill at %d: %x [%x]", fetch_offset, bus.resp, decode_buffer);
					fetch_offset <= fetch_offset + 8;
				end				
			end
			else begin
				if (fetch_state == fetch_active) begin
					fetch_state <= fetch_idle;
				end
				else if (bus.reqack) begin
					assert(fetch_state == fetch_idle) else $fatal;
					fetch_state <= fetch_waiting;
				end
			end
		end
	end
	
	// NOTE: buffer bits are left-to-right in increasing order
	wire [0:(128+15)*8-1] decode_bytes_repeated = { decode_buffer, decode_buffer[0:15*8-1] }; 
	wire [0:15*8-1] decode_bytes = decode_bytes_repeated[decode_offset*8 +: 15*8];
	
	// can decode if there is an instruction (4-bytes) in the decode buffer
	wire can_decode = (fetch_offset - decode_offset >= 7'd4);

	logic[3:0] bytes_decoded_this_cycle;
	always_comb begin
		if (can_decode) begin : decode_block
			// cse502 : Decoder here
			// remove the following line. It is only here to allow successful compilation in the absence of your code.
			if (decode_bytes == 0) ;

			// cse502 : following is an example of how to finish the simulation
			if (decode_bytes == 0 && fetch_state == fetch_idle) $finish;
		end
		else begin
			bytes_decoded_this_cycle = 0;
		end
	end

	always @(posedge bus.clk) begin
		if (bus.reset) begin
			decode_offset <= 0;
			decode_buffer <= 0;
		end
		else begin
			decode_offset <= decode_offset + {3'b0, bytes_decoded_this_cycle };
		end
	end
	
	// cse502 : Use the following as a guide to print the Register File contents.
	final begin
		$display("g00  = %x", 0);
		$display("g01  = %x", 0);
		$display("g02  = %x", 0);
		$display("g03  = %x", 0);
		$display("g04  = %x", 0);
		$display("g05  = %x", 0);
		$display("g06  = %x", 0);
		$display("g07  = %x", 0);
		$display("w00  = %x", 0);
		$display("w01  = %x", 0);
		$display("w02  = %x", 0);
		$display("w03  = %x", 0);
		$display("w04  = %x", 0);
		$display("w05  = %x", 0);
		$display("w06  = %x", 0);
		$display("w07  = %x", 0);
		$display("w08  = %x", 0);
		$display("w09  = %x", 0);
		$display("w10  = %x", 0);
		$display("w11  = %x", 0);
		$display("w12  = %x", 0);
		$display("w13  = %x", 0);
		$display("w14  = %x", 0);
		$display("w15  = %x", 0);
		$display("w16  = %x", 0);
		$display("w17  = %x", 0);
		$display("w18  = %x", 0);
		$display("w19  = %x", 0);
		$display("w20  = %x", 0);
		$display("w21  = %x", 0);
		$display("w22  = %x", 0);
		$display("w23  = %x", 0);
	end
endmodule
