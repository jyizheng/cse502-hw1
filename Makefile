.PHONY: all progs run clean submit

TRACE=--trace

LIBPATH=/home/stufs1/vagrawal/cse502-tools/lib 
INCPATH=/home/stufs1/vagrawal/cse502-tools/include

VFILES=$(wildcard *.sv)
CFILES=$(wildcard *.cpp)

VTOP_COMMAND_LINE=

all: obj_dir/Vtop

obj_dir/Vtop: obj_dir/Vtop.mk
	$(MAKE) -j2 -C obj_dir/ -f Vtop.mk CXX="ccache g++"

obj_dir/Vtop.mk: $(VFILES) $(CFILES) 
	verilator  -Wall -Wno-LITENDIAN -Wno-lint -O3 $(TRACE) --no-skip-identical --cc top.sv \
	--exe $(CFILES) ../dramsim2/libdramsim.so --top-module top \
	-CFLAGS -I$(INCPATH) -LDFLAGS -Wl,-rpath=../dramsim2/ -LDFLAGS -L$(LIBPATH) \


run: obj_dir/Vtop
	cd obj_dir/ && ./Vtop $(VTOP_COMMAND_LINE)

clean:
	rm -rf obj_dir/ trace.vcd core

SUBMIT_SUFFIX=HW1
SUBMIT_SCRIPT=/home/facfs1/nhonarmand/cse502/submit.sh
submit: clean
	rm -f $(USER).tgz $(USER).tgz.gpg
	tar -czvf $(USER).tgz --exclude=.*.sw? --exclude=$(USER).tgz* --exclude=*~ --exclude=.git *
	@gpg --quiet --import submit-pubkey.txt
	gpg --yes --encrypt --recipient 'cse502-submit' $(USER).tgz
	chmod o+r $(USER).tgz.gpg
	$(SUBMIT_SCRIPT) $(SUBMIT_SUFFIX) $(USER).tgz.gpg
