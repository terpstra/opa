#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "jtag.h"

int main(int argc, const char** argv) {
  bb_open(0x9fb, 0x6001);
  opa_probe(99);

  if (argc != 2) {
    printf("Must specify gpio state\n");
    return 1;
  }
  
  opa_gpio(strtoul(argv[1], 0, 0));
  bb_execute();
  
  bb_close();
  return 0;
}
