#include <string.h>
#include "pp-printf.h"

signed short  buf1[16] = { 0, -1,  2, -3,  4, -5,  6, -7,  8, -9,  10, -11, 12, -13,  14, -15 };
unsigned char buf2[16] = { 0,  1, -2, -3,  4,  5, -6, -7,  8,  9, -10, -11, 12,  13, -14, -15 };
const char hello[] = "hello world";

#ifndef HOST
volatile unsigned int* stdout = (unsigned int*)0xFFFFFFFCU;

int puts(const char *s) {
  while (*s) *stdout = *s++;
  *stdout = '\n';
  return 1;
}

int my_getchar() {
  static int but = 0, old = 0;
  
  while (1) {
    unsigned int x = *stdout;

    // Report button activity
    old = but;
    but = x >> 31;
    if (but != old) {
      pp_printf("Button: %s", but?"pushed":"released");
    }
    
    // Read data from JTAG?
    if (0 != (x & 0x100)) {
      return x & 0xFF;
    }
  }
}

void* memset(void* x, int c, size_t n)
{
  unsigned char *b = x;
  for (; n > 0; --n) *b++ = c;
  return x;
}
#else
extern int getchar();
int my_getchar() {
  return getchar();
}
#endif

void suduko();

void msleep(int x) {
  int i, j;
  for (i = 0; i < x; ++i) {
    // On a fast2 OPA, each loop iteration takes exactly 1 cycle
    // Thus, at 50MHz / 50000 = 1kHz => 1ms
    for (j = 0; j < 50000; ++j)
      asm volatile ("");
  }
}

int main() {
  int sum = 0;
  int i, j;
  
  pp_printf("I say: '%s'", hello);
  
  for (j = 0; j < 2; ++j) {
    // first iteration should be full of cache misses. second should be a rocket.
    for (i = 0; i < 16; ++i) {
      sum += buf1[i] * buf2[i] + (buf2[i] << i);
      buf1[i] = sum;
    }
  }
  
  pp_printf("Result: %x %d", sum, sum);
  
  // Run the suduko solver
  suduko();

  return sum;
}
