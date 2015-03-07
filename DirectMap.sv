/**
 * A write-allocate, write-back direct-mapped cache
 */
module DirectMap(
    CacheInterface.Bottom cif,
    SysBus.Top bus
);

    // bytes per word
    parameter WORD_SIZE = 4;
    // words per line
    parameter LOG_WORDS_PER_LINE = 4;
    // input address width, does not include block-offset bits
    parameter ADDR_WIDTH = 64-6;
    // log2 of # of sets in the cache (= # index bits)
    parameter LOG_NUM_SETS = 10;
 
    localparam WORDS_PER_LINE = 2**LOG_WORDS_PER_LINE;
    localparam WORD_SIZE_BITS = WORD_SIZE * 8;
    localparam NUM_SETS = 2**LOG_NUM_SETS;
    localparam LINE_SIZE = WORD_SIZE * WORDS_PER_LINE;
    localparam LINE_SIZE_BITS = LINE_SIZE * 8;

    localparam MAX_INDEX_BIT = LOG_NUM_SETS - 1;
    localparam MAX_LINE_BIT = LINE_SIZE_BITS - 1;
    localparam MAX_TAG_BIT = ADDR_WIDTH - LOG_NUM_SETS - 1;

    /* This is index to the sram */	
    logic[MAX_INDEX_BIT:0] index;

    /* data is 512 bit one row */
    logic data_en;
    logic data_rst;
    logic[MAX_LINE_BIT:0] data_wr;
    logic[MAX_LINE_BIT:0] data_rd;

    /* 2 bits state */
    logic state_en;
    logic state_rst;
    logic[1:0] state_rd;
    logic[1:0] state_wr;

    /* 48 bits tag */
    logic tag_en;
    logic tag_rst;
    logic[MAX_TAG_BIT:0] tag_rd;
    logic[MAX_TAG_BIT:0] tag_wr;

    /* output of cache  module */	
    logic[WORD_SIZE_BITS-1:0] data_out;
    logic ack;

    logic hit;
    logic alloc_or_wb;
    integer counter;
    logic read_one_word;

    /* Bypass a bug */
    logic clk;
    assign index = cif.line_addr[MAX_INDEX_BIT:0];
    assign clk = bus.clk;

    assign state_rst=bus.reset; 	
    assign tag_rst=bus.reset; 	
    assign data_rst=bus.reset;

    // instantiate separate SRAMs for state, tag and data
    SRAM # (2, LOG_NUM_SETS, 2) state(.clk(clk), .reset(data_rst),
				      .readAddr(index), .readData(state_rd),
				      .writeAddr(index),
				      .writeData(state_wr),
                                      .writeEnable(state_en));

    SRAM # (MAX_TAG_BIT+1, LOG_NUM_SETS, MAX_TAG_BIT+1) tag(.clk(clk), .reset(tag_rst),
				      .readAddr(index), .readData(tag_rd),
                                      .writeAddr(index),
				      .writeData(tag_wr),
                                      .writeEnable(tag_en));

    SRAM # (MAX_LINE_BIT+1, LOG_NUM_SETS, MAX_LINE_BIT+1) data(.clk(clk), .reset(data_rst),
					 .readAddr(index), .readData(data_rd),
                                         .writeAddr(index),
                                         .writeData(data_wr),
                                         .writeEnable(data_en));

    typedef enum { idle, cmp_tag, alloc, wait_wr_line, set_ack,
		   write_back, write_data
		 } cache_state_t;

    cache_state_t  cstate;
    assign cif.data_out = data_out;
    assign cif.ack = ack;

    always_comb begin
	if (cstate == cmp_tag) begin
		/* Don't pop from tx_queue */
		bus.respack = 'b0;

	    	if (tag_rd == cif.line_addr[ADDR_WIDTH-1:LOG_NUM_SETS] && state_rd[1]) begin
			hit = 1'b1;
		end else begin
			hit = 1'b0;
			/* data in the cache is useless */
			if (state_rd[0] == 1'b0 || state_rd[1] == 1'b0) begin
				alloc_or_wb = 1'b1;
			end else begin
				/* write back the current line */
				alloc_or_wb = 1'b0;
			end
		end 
	end else if (cstate == alloc) begin
		if (bus.respcyc) begin
        		$display("bus.resp %d is %x",counter, bus.resp);
			bus.respack = 1'b1;
			read_one_word = 1'b1;
			data_wr[0+counter*64 +: 63] = bus.resp;
		end else begin
			read_one_word = 1'b0;
		end
        	//$display("tag_rd: %x", tag_rd);
        	//$display("state_rd: %x", state_rd);

	end else if (cstate == wait_wr_line) begin
	    	bus.respack = 1'b1;

	end else if (cstate == idle) begin
	   	 /* reinitialization */
	    	hit = '0;
	    	alloc_or_wb = '0;
                read_one_word = '0;
    	end
    end

    // implement the cache logic
    always_ff @(posedge bus.clk) begin 
        if (bus.reset || !cif.req) begin
	    data_out <= '0;
	    ack <= '0;
	    cstate <= idle;

	end else if (cstate == idle) begin
	    cstate <= cmp_tag;
	    data_out <= '0;
	end else if (cstate == set_ack) begin
	    cstate <= idle;
	    ack <= 1'b1;

	end else if (cstate == cmp_tag) begin

	    if (hit) begin 	
            	$display("This is a cache hit");
		data_out <= data_rd[0+32*cif.word_select +: 31];
		cstate <= set_ack;
        	$display("data_rd is %x", data_rd);

	    end else if (alloc_or_wb) begin
	    	tag_en <= 1'b1;  
	    	tag_wr <= cif.line_addr[ADDR_WIDTH-1:LOG_NUM_SETS];
            	
		state_en <= 1'b1;
	    	state_wr <= {1'b1, ~cif.read_write_n};

		/* Issue a memory read request */
	    	bus.reqcyc <= 1'b1;
		bus.req <= {6'b0, cif.line_addr};
		bus.reqtag <= 13'h1100;
		cstate <= alloc;
		counter <= 3'b0;
	    end else 
            	$display("This is a cache miss need write back");
	end else if (cstate == alloc) begin
	    if (counter == 7) begin
		cstate <= wait_wr_line;
        	$display("data_wr is %x", data_wr);
		data_en <= 1'b1;
	    end else if (read_one_word) begin
		bus.reqcyc <= 1'b0;
		counter <= counter + 1;
        	$display("data_wr is %x", data_wr);
	    end
	end else if (cstate == wait_wr_line) begin
		cstate <= cmp_tag;
        end else
        	$display("Nothing to do");
   end

endmodule    
    
