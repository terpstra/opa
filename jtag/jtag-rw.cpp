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
