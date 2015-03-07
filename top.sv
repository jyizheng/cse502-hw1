module top(
	input  clk,
	       reset,
	      
	// bus interface
	output reqcyc,
		respack,
               	[63:0] req,
	       	[12:0] reqtag,
	input  	respcyc,
	       	reqack,
           	[63:0] resp,
	       [12:0] resptag,
	
	// processor interface
	output c_ack,
	       [31:0] c_data_out,
	input  c_req,
	       c_read_write_n,
	       [57:0] c_line_addr,
	       [31:0] c_data_in,
	       [3:0] c_word_select
);

	// instantiate the interfaces
	CacheInterface #(4, 4, 64-6) cif();
	SysBus #(64, 13) bus(.reset(reset), .clk(clk));
		
	// instantiate the cache
	// it has 16 words of 4 bytes each per line (each line = 64B)
	// The cache only has 2**4=16 sets to make sure block replacement happens
	DirectMap #(4, 4, 64-6, 4) cache(.cif(cif), .bus(bus));
	
	// bus plumbing - just to take the bus signals to the module ports
	assign req = bus.req;
	assign reqtag = bus.reqtag;
	assign reqcyc = bus.reqcyc;
	assign respack = bus.respack;
	assign bus.respcyc = respcyc;
	assign bus.reqack = reqack;
    	assign bus.resp = resp;
	assign bus.resptag = resptag;
	
	// cache-proc plumbing - just to take the cif signals to the module ports
	assign c_ack = cif.ack;
	assign c_data_out = cif.data_out;
	assign cif.req = c_req;
	assign cif.read_write_n = c_read_write_n;
	assign cif.line_addr = c_line_addr;
	assign cif.data_in = c_data_in;
	assign cif.word_select = c_word_select;	
endmodule // top


