.PHONY: run clean submit

RUNELF=$(PWD)/sparc-prog/hw.exe

TRACE=--trace

LIBPATH=/home/stufs1/vagrawal/cse502-tools/lib 
INCPATH=/home/stufs1/vagrawal/cse502-tools/include

VFILES=$(wildcard *.sv)
CFILES=$(wildcard *.cpp)

obj_dir/Vtop: obj_dir/Vtop.mk
	$(MAKE) -C $(PWD)/sparc-linux
	$(MAKE) -j2 -C obj_dir/ -f Vtop.mk CXX="ccache g++"

obj_dir/Vtop.mk: $(VFILES) $(CFILES) 
	verilator -Wall -Wno-LITENDIAN -O3 $(TRACE) --no-skip-identical --cc top.sv \
	--exe $(CFILES) ../dramsim2/libdramsim.so $(PWD)/sparc-linux/syscall.o \
	-CFLAGS -I$(INCPATH) -CFLAGS -I$(PWD)/sparc-linux \
	-LDFLAGS -Wl,-rpath=../dramsim2/ -LDFLAGS -L$(LIBPATH) \
	-LDFLAGS -lncurses -LDFLAGS -lelf

run: obj_dir/Vtop
	cd obj_dir/ && ./Vtop $(RUNELF)

clean:
	$(MAKE) -C $(PWD)/sparc-linux clean
	rm -rf obj_dir/ trace.vcd

SUBMIT_SUFFIX=PROJ
SUBMIT_SCRIPT=/home/facfs1/nhonarmand/cse502/submit.sh
submit: clean
	rm -f $(USER).tgz $(USER).tgz.gpg
	tar -czvf $(USER).tgz --exclude=.*.sw? --exclude=$(USER).tgz* --exclude=*~ --exclude=.git *
	@gpg --quiet --import submit-pubkey.txt
	gpg --sign --recipient 'cse502-submit' $(USER).tgz
	chmod o+r $(USER).tgz.gpg
	$(SUBMIT_SCRIPT) $(SUBMIT_SUFFIX) $(USER).tgz.gpg

