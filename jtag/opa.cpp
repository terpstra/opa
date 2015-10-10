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

static const uint64_t user1 = 0xe;
static const uint64_t user0 = 0xc;
static const int ir_width = 10;

static uint64_t ir_uart = 0;
static uint64_t ir_gpio = 0;
static uint64_t ir_addr = 0;
static uint64_t ir_data = 0;
static int vir_width;

// 1 -> 0
// 2 -> 1
// 3 -> 2
// 4 -> 2
// 5 -> 3
static int ceil_log2(int x) {
  int out = 0;
  while (x > 1) {
    ++out;
    x = (x+1)/2;
  }
  return out;
}

void vir(uint64_t vir)
{
  bb_shIR64(user1, ir_width);
  bb_shDR64(vir,   vir_width);
  bb_shIR64(user0, ir_width);
}

void opa_uart(uint32_t dat)
{
  if (!ir_uart) {
    fprintf(stderr, "no gpio JTAG core in target device\n");
    exit(1);
  }
  vir(ir_uart);
  bb_shDR64(dat, 9, 1);
}

void opa_gpio(uint8_t data)
{
  if (!ir_gpio) {
    fprintf(stderr, "no gpio JTAG core in target device\n");
    exit(1);
  }
  vir(ir_gpio);
  bb_shDR64(data, 6);
}

void opa_read(uint64_t address)
{
  if (!ir_addr) {
    fprintf(stderr, "no loader JTAG core in target device\n");
    exit(1);
  }
  vir(ir_addr);
  bb_shDR64(address, 32);
  vir(ir_data);
  bb_shDR64(0, 32, 1);
}

void opa_write(uint64_t address, uint64_t value, int old)
{
  if (!ir_addr) {
    fprintf(stderr, "no loader JTAG core in target device\n");
    exit(1);
  }
  static int leds = 1;
  
  vir(ir_addr);
  bb_shDR64(address, 32);
  vir(ir_data);
  bb_shDR64(value, 32, old);
  vir(ir_gpio);
  bb_shDR64(0x10 | leds, 6);
  
  // rotate LEDs each write to indicate progress
  leds <<= 1;
  if (leds == 0x10) leds = 1;
}

void opa_probe(int loader_id, int uart_id) {
  bb_reset();
  bb_execute();
  
  bb_shDR64(0xdeadbeefU, 64, 1);
  uint64_t idcode = bb_execute64();
  
  if ((idcode >> 32) != 0xdeadbeefU) {
    fprintf(stderr, "More than one JTAG device attached to chain is not supported\n");
    exit(1);
  }
  idcode &= 0xffffffffU;
  
  switch (idcode) {
  case 0x02a010ddU: fprintf(stderr, "Arria V detected\n"); break;
  case 0x02b150ddU: fprintf(stderr, "Cyclone V detected\n"); break;
  default: fprintf(stderr, "Unknown device; idcode = 0x%08x\n", (int)idcode); exit(1);
  }

  // Scan the HUB_INFO
  bb_shIR64(user1, ir_width);
  bb_shDR64(0, 64);
  bb_shIR64(user0, ir_width);
  for (int i = 0; i < 8; ++i) bb_shDR64(0, 4, 1);
  std::vector<unsigned char> hubvec = bb_execute();
  
  int m       =                            (hubvec[1] << 4) | hubvec[0];
  int hub_mfg = ((hubvec[4] & 0x7) << 8) | (hubvec[3] << 4) | hubvec[2];
  int N       = ((hubvec[6] & 0x7) << 5) | (hubvec[5] << 1) | (hubvec[4] >> 3);
  int hub_ver =                            (hubvec[7] << 1) | (hubvec[6] >> 3);
  // printf("m = %d, N = %d, ver = %d, mfg = %x\n", m, N, hub_ver, hub_mfg);
  
  if (hub_mfg != 0x6e || hub_ver != 1) {
    fprintf(stderr, "Unsupported SLD hub\n");
    exit(1);
  }
  fprintf(stderr, "SLD hub located\n");
  
  // Scan all the SLD nodes
  int loaderdev = -1;
  int uartdev = -1;
  for (int dev = 1; dev <= N; ++dev) {
    for (int i = 0; i < 8; ++i) bb_shDR64(0, 4, 1);
    std::vector<unsigned char> nodevec = bb_execute();
    
    int inst_id  =                             (nodevec[1] << 4) | nodevec[0];
    int node_mfg = ((nodevec[4] & 0x7) << 8) | (nodevec[3] << 4) | nodevec[2];
    int node_id  = ((nodevec[6] & 0x7) << 5) | (nodevec[5] << 1) | (nodevec[4] >> 3);
    int node_ver =                             (nodevec[7] << 1) | (nodevec[6] >> 3);
    
    // printf("ver = %d, mfg = %x, id = %d, inst_id = %d\n", node_ver, node_mfg, node_id, inst_id);
    if (node_mfg == 0x6e && node_ver == 0 && node_id == 8) {
      if (inst_id == loader_id) loaderdev = dev;
      if (inst_id == uart_id) uartdev = dev;
    }
  }
  
  uint32_t n = ceil_log2(N+1); // USER1 DR width = (n, m)-bit tuple
  vir_width = n + m;
  
  vir_width = n + m;
  
  if (loaderdev != -1) {
    ir_gpio = ((uint64_t)loaderdev << m) | 0;
    ir_addr = ((uint64_t)loaderdev << m) | 2;
    ir_data = ((uint64_t)loaderdev << m) | 3;
  }
  if (uartdev != -1) {
    ir_uart = ((uint64_t)uartdev << m) | 0;
  }
}
