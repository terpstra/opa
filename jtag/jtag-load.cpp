#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "jtag.h"

int main(int argc, const char** argv) {
  FILE* f;
  unsigned char buf[4];
  uint32_t address = 0, data, last;
  
  bb_open();
  opa_probe();
  
  if (argc != 3) {
    fprintf(stderr, "syntax: jtag-load <b|l> <file>\n");
    return 1;
  }
  
  bool big_endian;
  switch (argv[1][0]) {
  case 'b': big_endian = true;  break;
  case 'l': big_endian = false; break;
  default: fprintf(stderr, "%s is neither b nor l endian\n", argv[1]); return 1;
  }
  
  if ((f = fopen(argv[2], "r")) == 0) {
    perror(argv[2]);
    return 1;
  }
  
  printf("Reading input     ... "); fflush(stdout);
  while (fread(&buf[0], 4, 1, f) != 0) {
    if (big_endian) {
      data = (buf[0] << 24) | (buf[1] << 16) | (buf[2] <<  8) | (buf[3] <<  0);
    } else {
      data = (buf[0] <<  0) | (buf[1] <<  8) | (buf[2] << 16) | (buf[3] << 24);
    }
    opa_write(address, data);
    address += 4;
  }
  last = address;
  printf("done\n");
  
  printf("Writing to FPGA   ... "); fflush(stdout);
  bb_execute();
  printf("done\n");
  
  printf("Reading from FPGA ... "); fflush(stdout);
  std::vector<unsigned char> result;
  for (address = 0; address != last; address += 4) {
    opa_read(address);
    if (address % 128 == 0) {
      std::vector<unsigned char> temp = bb_execute();
      result.insert(result.end(), temp.begin(), temp.end());
    }
  }
  std::vector<unsigned char> temp = bb_execute();
  result.insert(result.end(), temp.begin(), temp.end());
  printf("done\n");
  
  printf("Verifying input   ... "); fflush(stdout);
  std::vector<unsigned char>::iterator i;
  rewind(f);
  for (i = result.begin(); i != result.end(); i += 4) {
    if (fread(&buf[0], 4, 1, f) != 1) break;
    if (big_endian) {
      if (i[0] != buf[3] || i[1] != buf[2] || i[2] != buf[1] || i[3] != buf[0]) break;
    } else {
      if (i[0] != buf[0] || i[1] != buf[1] || i[2] != buf[2] || i[3] != buf[3]) break;
    }
  }
  if (i != result.end()) {
    printf("FAILED!!!!\n");
  } else {
    printf("done\n");
    printf("Starting CPU      ... "); fflush(stdout);
    opa_gpio(32);
    bb_execute();
    printf("done\n");
  }
  
  bb_close();
  return 0;
}
