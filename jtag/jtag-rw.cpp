#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "jtag.h"

int main(int argc, const char** argv) {
  bb_open();
  opa_probe();

  uint32_t address = 0, data = 0;
  if (argc > 1) address = strtoul(argv[1], 0, 0);
  if (argc > 2) data    = strtoul(argv[2], 0, 0);
  
  // Note: executing read/write puts CPU into reset and leaves it there
  if (argc == 2) {
    opa_read(address);
    printf("read(0x%x) = 0x%x\n", address, (uint32_t)bb_execute64());
  } else if (argc == 3) {
    opa_write(address, data, 1);
    printf("write(0x%x) = 0x%x (was 0x%x)\n", address, data, (uint32_t)bb_execute64());
  }
  
  bb_close();
  return 0;
}
