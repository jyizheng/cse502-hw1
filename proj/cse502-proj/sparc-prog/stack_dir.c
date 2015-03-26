#include <stdlib.h>
#include <stdio.h>

static int find_stack_direction() {
  static char *addr = 0;
  char dummy;

  if (addr == 0) {
      addr = &dummy;
      return find_stack_direction();
  }
  else {
      return ((&dummy > addr) ? 1 : -1);
  }
}

int main(void) {
  if (find_stack_direction() > 0)
    printf("Stack grows towards higher addrs.\n");
  else
    printf("Stack grows towards lower addrs.\n");

  return 0;
}
