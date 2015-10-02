#include <vector>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include "bb.h"

static const uint64_t user1 = 0xe;
static const uint64_t user0 = 0xc;
static const int ir_width = 10;

static uint64_t ir_gpio;
static uint64_t ir_addr;
static uint64_t ir_data;
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

void vread(uint64_t address)
{
  vir(ir_addr);
  bb_shDR64(address, 32);
  vir(ir_data);
  bb_shDR64(0, 32, 1);
}

void vwrite(uint64_t address, uint64_t value, int old = 0)
{
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

int main(int argc, const char** argv) {
  int seek_inst_id = 99;

  bb_open(0x9fb, 0x6001);

  bb_reset();
  bb_execute();
  
  bb_shDR64(0xdeadbeefU, 64, 1);
  uint64_t idcode = bb_execute64();
  
  if ((idcode >> 32) != 0xdeadbeefU) {
    fprintf(stderr, "More than one JTAG device attached to chain is not supported\n");
    return 1;
  }
  idcode &= 0xffffffffU;
  
  switch (idcode) {
  case 0x02a010ddU: fprintf(stderr, "Arria V detected\n"); break;
  case 0x02b150ddU: fprintf(stderr, "Cyclone V detected\n"); break;
  default: fprintf(stderr, "Unknown device; idcode = 0x%08x\n", (int)idcode); return 1;
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
    return 1;
  }
  fprintf(stderr, "SLD hub located\n");
  
  // Scan all the SLD nodes
  int devid = -1;
  for (int dev = 1; dev <= N; ++dev) {
    for (int i = 0; i < 8; ++i) bb_shDR64(0, 4, 1);
    std::vector<unsigned char> nodevec = bb_execute();
    
    int inst_id  =                             (nodevec[1] << 4) | nodevec[0];
    int node_mfg = ((nodevec[4] & 0x7) << 8) | (nodevec[3] << 4) | nodevec[2];
    int node_id  = ((nodevec[6] & 0x7) << 5) | (nodevec[5] << 1) | (nodevec[4] >> 3);
    int node_ver =                             (nodevec[7] << 1) | (nodevec[6] >> 3);
    
    // printf("ver = %d, mfg = %x, id = %d, inst_id = %d\n", node_ver, node_mfg, node_id, inst_id);
    if (node_mfg == 0x6e && node_ver == 0 && node_id == 8) {
      if (inst_id == seek_inst_id) devid = dev;
    }
  }
  
  if (devid == -1) {
    fprintf(stderr, "Could not find SLD node %d\n", seek_inst_id);
    return 1;
  }
  
  uint32_t n = ceil_log2(N+1); // USER1 DR width = (n, m)-bit tuple
  vir_width = n + m;
  fprintf(stderr, "SLD device (%d) at address %d in %d-sized VIR\n", seek_inst_id, devid, vir_width);
  
  vir_width = n + m;
  ir_gpio = ((uint64_t)devid << m) | 0;
  ir_addr = ((uint64_t)devid << m) | 2;
  ir_data = ((uint64_t)devid << m) | 3;
  
  uint32_t address = 0, data = 0;
  if (argc > 1) address = strtoul(argv[1], 0, 0);
  if (argc > 2) data    = strtoul(argv[2], 0, 0);
  
  if (argc == 2) {
    vread(address);
    printf("read(0x%x) = 0x%x\n", address, (uint32_t)bb_execute64());
  } else if (argc == 3) {
    vwrite(address, data, 1);
    printf("write(0x%x) = 0x%x (was 0x%x)\n", address, data, (uint32_t)bb_execute64());
  }
  
  bb_close();
  return 0;
}
