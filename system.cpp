#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <assert.h>
#include <stdlib.h>
#include <iostream>
#include <arpa/inet.h>
#include "system.h"
#include "Vtop_top.h"

using namespace std;

/**
 * Bus request tag fields
 */
enum {
    READ   = 0b1,
    WRITE  = 0b0,
    MEMORY = 0b0001,
    MMIO   = 0b0011,
    PORT   = 0b0100,
    IRQ    = 0b1110
};

#ifndef be32toh
#define be32toh(x)      ((u_int32_t)ntohl((u_int32_t)(x)))
#endif

static __inline__ u_int64_t cse502_be64toh(u_int64_t __x) { return (((u_int64_t)be32toh(__x & (u_int64_t)0xFFFFFFFFULL)) << 32) | ((u_int64_t)be32toh((__x & (u_int64_t)0xFFFFFFFF00000000ULL) >> 32)); }

/** Current simulation time */
uint64_t main_time = 0;
const int ps_per_clock = 500;
double sc_time_stamp() {
    return main_time;
}

#include <sys/time.h>
#include <unistd.h>

System::System(Vtop* top, unsigned ramsize, int ps_per_clock)
    : top(top), ramsize(ramsize), rx_count(0)
{
    ram = (char*) malloc(ramsize);
    assert(ram);
    memset(ram, 0, ramsize);
    
	// create the dram simulator
    dramsim = DRAMSim::getMemorySystemInstance("DDR2_micron_16M_8b_x8_sg3E.ini", "system.ini", "../dramsim2", "dram_result", ramsize / MEGA);
    DRAMSim::TransactionCompleteCB *read_cb = new DRAMSim::Callback<System, void, unsigned, uint64_t, uint64_t>(this, &System::dram_read_complete);
    DRAMSim::TransactionCompleteCB *write_cb = new DRAMSim::Callback<System, void, unsigned, uint64_t, uint64_t>(this, &System::dram_write_complete);
    dramsim->RegisterCallbacks(read_cb, NULL, NULL);
    dramsim->setCPUClockSpeed(1000ULL*1000*1000*1000/ps_per_clock);
}

System::~System() {
    free(ram);
}

void System::procTick(int clk) {
	
        //cerr << "reset:" << std::hex << (int)top->reset << endl;
	// reset? 
	if (top->reset) {
		// nothing for now
		return;
	}
	

        //cerr << "req:" << std::hex << (int)top->c_req<< endl;
        //cerr << "arc:" << std::hex << (int)top->c_ack<< endl;

	// is there an outstanding request? wait until done.
	if (top->c_req && !top->c_ack) {
		return;
	}
	
	// issue all the processor requests on the negedge so that
	// the processor can act on it on the next posedge		
	if (! top->clk) {
		
		// if current request is done
		if (top->c_ack) {
			// drop the req line
			top->c_req = 0;
			
			// if it was a read request, check if the result is consistent 
			// with previous writes

			// NOTE: this is to test your design to make sure it is correct
			// NOTE: to properly implement the testing, you might need to
			//       add code elsewhere too.
			//		
			// @YOUR CODE HERE ...

                	cerr << "Data:" << std::hex << top->c_data_out << endl;
			return;
		}

   	 	struct timeval tv;
    		struct timezone tz;
    		gettimeofday (&tv, &tz);

		//randomly wait before issuing the next request
		srand(time(NULL));
		if ((tv.tv_sec + tv.tv_usec + rand()) % 5 == 0) {
                	cerr << "Wait:" << std::hex << (int)top->c_req << endl;
			return;
		}

		// issue a new request
		top->c_req = 1;
		top->c_read_write_n = 0; //rand() % 2;

		srand(time(NULL));
		if ((tv.tv_sec + tv.tv_usec + rand()) % 2) {

			srand(time(NULL));
			unsigned int addr = (tv.tv_sec + tv.tv_usec + rand())% ramsize;
			//top->c_line_addr = addr & ~0x3FU;
			top->c_line_addr = addr >> 6;
			srand(2);
			top->c_word_select = rand() % 16;

		} else {
			cerr << "fix address"  << endl;
			//top->c_line_addr = 0x1eeef & ~0x3FU;
			top->c_line_addr = 0x1eeef >> 6;
			top->c_word_select = (tv.tv_sec + tv.tv_usec + rand()) % 16;
		}

                cerr << "Address:" << std::hex << top->c_line_addr << endl;
                cerr << "Select:"  << std::hex << (int)top->c_word_select << endl;
		
		if (! top->c_read_write_n) {
			// write operation
			srand(time(NULL));
			top->c_data_in = 0xdeadbeef;
		}
	}
}

void System::ramTick(int clk) {
    
    if (top->reset && top->reqcyc) {
        cerr << "Sending a request on RESET. Ignoring..." << endl;
        return;
    }
    
    if (!clk) {
        if (top->reqcyc) {
            // hack: blocks ACK if /any/ memory channel can't accept transaction
            top->reqack = dramsim->willAcceptTransaction();
            // if trnasfer is in progress, can't change mind about willAcceptTransaction()
            assert(!rx_count || top->reqack); 
        }
        return;
    }

    dramsim->update();
    if (!tx_queue.empty() && top->respack) { 
	tx_queue.pop_front();
	cerr << "Delete an element" << endl; 
	cerr << "tx_queue size:" << tx_queue.size() << endl;
    }

    if (!tx_queue.empty()) {
        top->respcyc = 1;
        top->resp = tx_queue.begin()->first;
        top->resptag = tx_queue.begin()->second;
        cerr << "responding data " << top->resp << " on tag " << std::hex << top->resptag << endl;
	return;
    } else {
        top->respcyc = 0;
        top->resp = 0xaaaaaaaaaaaaaaaaULL;
        top->resptag = 0xaaaa;
    }

    // cerr << "top->reqcyc" <<(int) top->reqcyc << endl;
    if (top->reqcyc) {
        cmd = (top->reqtag >> 8) & 0xf;
        
        if (rx_count) {
			
            switch(cmd) {
            case MEMORY:
		// critical word first
                *((uint64_t*)(&ram[((xfer_addr&(~63))+((xfer_addr + ((8-rx_count)*8))&63))])) = cse502_be64toh(top->req);
                cerr << "Data written: " << std::hex << cse502_be64toh(top->req) << endl;
                break;
            default:
		assert(false);
            }
            
            --rx_count;
            return;
        }
                
        bool isWrite = ((top->reqtag >> 12) & 1) == WRITE;
        if (cmd == MEMORY && isWrite)
            rx_count = 8;
        else if (cmd == MMIO && isWrite)
            rx_count = 1;
        else
            rx_count = 0;
            
        switch(cmd) {
        case MEMORY:
            xfer_addr = top->req;
            assert(!(xfer_addr & 7));
            if (addr_to_tag.find(xfer_addr)!=addr_to_tag.end()) {
                //cerr << "Access for " << std::hex << xfer_addr << " already outstanding. Ignoring..." << endl;
            } else {
                assert(
                    dramsim->addTransaction(isWrite, xfer_addr)
                );
                cerr << "add transaction " << std::hex << xfer_addr << " on tag " << top->reqtag << endl;
                if (!isWrite) addr_to_tag[xfer_addr] = top->reqtag;

    		if (!tx_queue.empty()) {
			cerr << "tx_queue size:" << tx_queue.size() << endl;
		}

            }
            break;

        default:
            assert(0);
        };
    }
    else {
        top->reqack = 0;
        rx_count = 0;
    }
}

void System::tick(int clk) {
	procTick(clk);
	ramTick(clk);
}

void System::dram_read_complete(unsigned id, uint64_t address, uint64_t clock_cycle) {
    
    map<uint64_t, int>::iterator tag = addr_to_tag.find(address);
    assert(tag != addr_to_tag.end());
    
    for(int i = 0; i < 64; i += 8) {
        tx_queue.push_back(make_pair(cse502_be64toh(*((uint64_t*)(&ram[((address&(~63))+((address+i)&63))]))) + i ,tag->second));
        cerr << "fill data from " << std::hex << (address+(i&63)) << ": " << tx_queue.rbegin()->first << " on tag " << tag->second << endl;
    }
    addr_to_tag.erase(tag);
}

void System::dram_write_complete(unsigned id, uint64_t address, uint64_t clock_cycle) {

    cerr << "I am write"  << endl;
}
