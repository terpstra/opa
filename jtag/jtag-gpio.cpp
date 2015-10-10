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

  if (argc != 2) {
    printf("Must specify gpio state\n");
    return 1;
  }
  
  opa_gpio(strtoul(argv[1], 0, 0));
  bb_execute();
  
  bb_close();
  return 0;
}
