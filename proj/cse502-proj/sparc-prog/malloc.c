#include <stdlib.h>
#include <stdio.h>

int main(void) {
  int i;
  char *test;

  for (i = 0; i < 1000; i++) {
    test = malloc(10000);
    printf("test is 0x%x\n", (void*)test);
  }

}
