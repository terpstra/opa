#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

#include "jtag.h"

int main(int argc, const char** argv) {
  const int grab = 10;
  
  bb_open();
  opa_probe();

  while (1) {
    for (int i = 0; i < grab; ++i)
      opa_uart(0);
    
    std::vector<unsigned char> got = bb_execute();
    for (int i = 0; i < grab; ++i)
      if (got[i*2+1]) fputc(got[i*2], stdout);
    
    if (!got[grab*2-1]) {
      fflush(stdout);
      usleep(10000); // 10ms
    }
  }
  
  bb_close();
  return 0;
}
