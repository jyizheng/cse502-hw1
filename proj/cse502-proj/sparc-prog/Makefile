CC = diet sparc-linux-gcc
CXX = diet sparc-linux-g++

EXES = hw.exe malloc.exe stack_dir.exe

all: $(EXES)

%.exe: %.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -rf *.o *.exe
