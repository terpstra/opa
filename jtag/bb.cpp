#include <deque>
#include <vector>
#include <ftdi.h>
#include <stdio.h>
#include <stdint.h>

#include "bb.h"

#define USE_BURST 1
// #define DEBUG_FTDI 1

#define BB_BMODE	0x80
#define BB_READ		0x40
#define BB_LED		0x20
#define BB_TDI		0x10
#define BB_NCS		0x08
#define BB_NCE		0x04
#define BB_TMS		0x02
#define BB_TCK		0x01

static struct ftdi_context ftdi;
static std::vector<unsigned char> buf;
static std::deque<int> reads;
static int reply;

static int my_min(int x, int y)
{
  return x ^ ((x ^ y) & -(x > y)); // min(x, y)
}

static void clock(int flags, int led = BB_LED)
{
  buf.push_back((flags&~BB_READ) | led);
  buf.push_back(flags            | led | BB_TCK);
}

static void shift(const unsigned char* send, int bits, int read)
{
  int i;
  int readf;
  unsigned char last, now;
  
  if (read) {
    reads.push_back(bits);
    readf = BB_READ;
  } else {
    readf = 0;
  }
  
  // byte-shift mode requires nCS set to work
  buf.push_back(BB_LED | BB_NCS);
  
  /* JTAG shifts bits during a rising edge while in the SHIFT-{IR,DR} state.
   * This includes the TMS=1 shift that takes you out of the shift state.
   * A shift means:
   *   you must supply TDI before the rising edge
   *   if you want to exit shift mode, supply TMS before rising edge
   *   you must sample TDO after the rising edge
   * When you use the burst mode of a byte blaster, it does:
   *   put requested bit on TDI and pull TCK low
   *   push TCK high and sample the bit on TDO
   * ... so you cannot leave shift mode with a burst.
   *
   * This sucks for multiple-of-8 registers, because you must stop the burst
   * and do the last 8 bits with bit-banging, just so you can set the last TMS.
   *
   * A trick to avoid this problem is to move the burst one bit earlier.
   * Thus you use burst mode for the transition from Select-{IR,DR} to {Capture-IR,DR}.
   * The consequence is that you need to send and receive one extra (0) data bit.
   */
  
  ++bits; // add a pad bit
  
  i = 0;
  last = 0;
  now = 0; // silence warning
#if USE_BURST
  // Last bit cannot be done with burst mode, so must be > 8
  while (bits-i > 8) { 
    int amt = my_min(63, (bits-i-1)/8); // number of bytes
    reply += read * amt;
    buf.push_back(amt | readf | BB_BMODE);
    for (; amt > 0; --amt) {
      now = *send++;
      buf.push_back(last | now << 1);
      last = now >> 7;
      i += 8;
    }
  }
#endif

  // when clocked INSIDE shift => data moves (doesn't matter if TMS=1/0)

  // Deal with trailing bits
  reply += read * (bits - i);
  while (1) {
    unsigned char dat = last * BB_TDI;
    
    if (i % 8 == 0) now = *send++;
    last = now & 1;
    now >>= 1;
    
    if (++i == bits) {
      clock(dat | readf | BB_TMS); // exit1
      break;
    } else {
      clock(dat | readf); // shift
    }
  }
}

std::vector<unsigned char> parse(const unsigned char* buf)
{
  std::vector<unsigned char> result;

  while (!reads.empty()) {
    int bits = reads.front();
    reads.pop_front();
    
    ++bits; // the pad bit
    unsigned char last = 0;
    unsigned int kill = result.size();
    
    int i = 0;
#if USE_BURST  
    while (bits-i > 8) { 
      int amt = my_min(63, (bits-i-1)/8); // number of bytes
      for (; amt > 0; --amt) {
        unsigned char got = *buf++;
        result.push_back(last | got << 7);
        last = got >> 1;
        i += 8;
      }
    }
#endif    
    
    while (1) {
      unsigned char dat = *buf++ << 7;
      last = last | dat;
      if (i % 8 == 0) result.push_back(last);
      if (++i == bits) break;
      last >>= 1;
    }
    
    if (i % 8 != 0) {
      // !!! not 100% sure about this:
      result.push_back(last >> ((bits-1) % 8));
    }
    
    // kill padding bit
    result.erase(result.begin() + kill);
  }

  reply = 0;
  return result;
}

void bb_reset()
{
  // unknown state
  clock(BB_TMS);
  clock(BB_TMS);
  clock(BB_TMS);
  clock(BB_TMS);
  clock(BB_TMS); // test logic reset
  clock(0, 0);   // run test idle
}

void bb_shIR64(uint64_t ir, int bits, int read)
{
  unsigned char buf[8] = {
    (unsigned char)(ir >>  0), (unsigned char)(ir >>  8),
    (unsigned char)(ir >> 16), (unsigned char)(ir >> 24),
    (unsigned char)(ir >> 32), (unsigned char)(ir >> 40),
    (unsigned char)(ir >> 48), (unsigned char)(ir >> 56)
  };
  
  // run test idle
  clock(BB_TMS); // select DR scan
  clock(BB_TMS); // select IR scan
  clock(0);      // capture IR
  shift(&buf[0], bits, read != 0);
  clock(BB_TMS); // update IR
  clock(0, 0);   // run test idle
}

void bb_shIR(const unsigned char* dr, int bits, int read)
{
  // run test idle
  clock(BB_TMS); // select DR scan
  clock(BB_TMS); // select IR scan
  clock(0);      // capture IR
  shift(dr, bits, read != 0);
  clock(BB_TMS); // update IR
  clock(0, 0);   // run test idle
}

void bb_shDR64(uint64_t ir, int bits, int read)
{
  unsigned char buf[8] = {
    (unsigned char)(ir >>  0), (unsigned char)(ir >>  8),
    (unsigned char)(ir >> 16), (unsigned char)(ir >> 24),
    (unsigned char)(ir >> 32), (unsigned char)(ir >> 40),
    (unsigned char)(ir >> 48), (unsigned char)(ir >> 56)
  };
  
  // run test idle
  clock(BB_TMS); // select DR scan
  clock(0);      // capture DR
  shift(&buf[0], bits, read != 0);
  clock(BB_TMS); // update DR
  clock(0, 0);   // run test idle
}

void bb_shDR(const unsigned char* dr, int bits, int read)
{
  // run test idle
  clock(BB_TMS); // select DR scan
  clock(0);      // capture DR
  shift(dr, bits, read != 0);
  clock(BB_TMS); // update DR
  clock(0, 0);   // run test idle
}

static void bb_write(const unsigned char* bufc, int len) {
  int sent = 0;
  int got = 0;
  
  // FTDI driver has missing const flag
  unsigned char *buf = const_cast<unsigned char*>(bufc);
  
  while (sent != len && (got = ftdi_write_data(&ftdi, buf+sent, len-sent)) >= 0)
    sent += got;

#if DEBUG_FTDI  
  fprintf(stderr, "<= ");
  for (int i = 0; i < len; ++i)
    fprintf(stderr, "%02x ", buf[i]);
  fprintf(stderr, "\n");
#endif

  if (got < 0) {
    fprintf(stderr, "ftdi_write_data: %s\n", ftdi_get_error_string(&ftdi));
    exit(1);
  }
}

static void bb_read(unsigned char* buf, int len) {
  int recv = 0;
  int got = 0;
  
  while (recv != len && (got = ftdi_read_data(&ftdi, buf+recv, len-recv)) >= 0)
    recv += got;

#ifdef DEBUG_FTDI  
  fprintf(stderr, "=> ");
  for (int i = 0; i < len; ++i)
    fprintf(stderr, "%02x ", buf[i]);
  fprintf(stderr, "\n");
#endif
  
  if (got < 0) {
    fprintf(stderr, "ftdi_read_data: %s\n", ftdi_get_error_string(&ftdi));
    exit(1);
  }
}

std::vector<unsigned char> bb_execute()
{
  bb_write(buf.data(), buf.size());
  buf.clear();
  unsigned char result[reply];
  bb_read(&result[0], reply);
  
  return parse(result);
}

uint64_t bb_execute64()
{
  uint64_t result = 0;
  std::vector<unsigned char> out = bb_execute();
  
  for (std::vector<unsigned char>::reverse_iterator i = out.rbegin(); i != out.rend(); ++i)
    result = result << 8 | *i;
  
  return result;
}

void bb_open(int vendor, int device)
{
  if (0 != ftdi_init(&ftdi) ||
      0 != ftdi_set_interface(&ftdi, INTERFACE_A)) {
    perror("ftdi_init");
    exit(1);
  }
  
  if (0 != ftdi_usb_open(&ftdi, vendor, device)) {
    fprintf(stderr, "ftdi_usb_open_dev: %s\n", ftdi_get_error_string(&ftdi));
    exit(1);
  }
  
  if (0 != ftdi_set_line_property2(&ftdi, BITS_8, STOP_BIT_1, NONE, BREAK_OFF) ||
      0 != ftdi_disable_bitbang(&ftdi) ||
      0 != ftdi_set_baudrate(&ftdi, 115200)) {
    fprintf(stderr, "ftdi_config: %s\n", ftdi_get_error_string(&ftdi));
    exit(1);
  }
  
  buf.clear();
  reads.clear();
  reply = 0;
}

void bb_close()
{
  ftdi_usb_close(&ftdi);
  ftdi_deinit(&ftdi);
}
