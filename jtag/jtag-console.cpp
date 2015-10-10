/*  opa: Open Processor Architecture
 *  Copyright (C) 2014-2016  Wesley W. Terpstra
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#include "jtag.h"

static void set_blocking(int fdes, int block) {
  int flags;
  
  flags = fcntl(fdes, F_GETFL);
  flags = (flags & ~O_NONBLOCK) | (block?0:O_NONBLOCK);
  fcntl(fdes, F_SETFL, flags);
}

int main(int argc, const char** argv) {
  const int grab = 10;
  unsigned char c;
  
  bb_open();
  opa_probe();
  set_blocking(0, 0);

  while (1) {
    for (int i = 0; i < grab; ++i)
      opa_uart((read(0, &c, 1) == 1) ? (c|0x100) : 0);
    
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
