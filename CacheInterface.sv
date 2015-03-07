/**
 * Cache-Processor Interface
 *
 * @req: there is a pending request to the cache.
 * @read_write_n: read if 1, write if 0;
 * @ack: cache acknowledges the request (read: data is ready; write: is finished)
 *
 * On a read, the cache returns the word indicated by @word_select from
 * the frame caching memory line @addr.
 *
 * On a write, the cache writes the word indicated by @word_select to
 * the frame caching memory line @addr.
 */
interface CacheInterface;
    
    // bytes per word
    parameter WORD_SIZE = 4;
    // words per line
    parameter LOG_WORDS_PER_LINE = 4;
    // input address width, does not include block-offset bits
    parameter ADDR_WIDTH = 64-6;
    
    localparam WORDS_PER_LINE = 2**LOG_WORDS_PER_LINE;
    localparam WORD_SIZE_BITS = WORD_SIZE * 8;
    
	wire req;
	wire ack;
    wire read_write_n;
    wire [ADDR_WIDTH-1:0] line_addr;
    wire [LOG_WORDS_PER_LINE-1:0] word_select;
    wire [WORD_SIZE_BITS-1:0] data_in;
    wire [WORD_SIZE_BITS-1:0] data_out;
	
	modport Top(input data_out, ack, output req, read_write_n, line_addr, data_in, word_select);
	modport Bottom(input req, read_write_n, line_addr, data_in, word_select, output ack, data_out);
endinterface
