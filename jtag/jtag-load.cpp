#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "jtag.h"

int main(int argc, const char** argv) {
  FILE* f;
  unsigned char buf[4];
  uint32_t address = 0, data;
  
  bb_open();
  opa_probe();
  
  if (argc != 2) {
    fprintf(stderr, "Must specify a file to load\n");
    return 1;
  }
  
  bool big_endian = true; // LM32
  
  if ((f = fopen(argv[1], "r")) == 0) {
    perror(argv[1]);
    return 1;
  }
  
  printf("Reading input   ... "); fflush(stdout);
  while (fread(&buf[0], 4, 1, f) != 0) {
    if (big_endian) {
      data = (buf[0] << 24) | (buf[1] << 16) | (buf[2] <<  8) | (buf[3] <<  0);
    } else {
      data = (buf[0] <<  0) | (buf[1] <<  8) | (buf[2] << 16) | (buf[3] << 24);
    }
    opa_write(address, data);
    address += 4;
  }
  printf("done\n");
  
  printf("Writing to FPGA ... "); fflush(stdout);
  bb_execute();
  printf("done\n");
  
  bb_close();
  return 0;
}
