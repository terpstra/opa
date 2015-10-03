#include "pp-printf.h"

signed short  buf1[16] = { 0, -1,  2, -3,  4, -5,  6, -7,  8, -9,  10, -11, 12, -13,  14, -15 };
unsigned char buf2[16] = { 0,  1, -2, -3,  4,  5, -6, -7,  8,  9, -10, -11, 12,  13, -14, -15 };
const char hello[] = "hello world";

#ifndef HOST
volatile unsigned int* stdout = (unsigned int*)0x80000000U;
int puts(const char *s) {
  while (*s) *stdout = *s++;
  *stdout = '\n';
  return 1;
}
#endif

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
  
  msleep(1000);
  
  pp_printf("I say: '%s'", hello);
  
  for (j = 0; j < 2; ++j) {
    // first iteration should be full of cache misses. second should be a rocket.
    for (i = 0; i < 16; ++i) {
      sum += buf1[i] * buf2[i] + (buf2[i] << i);
      buf1[i] = sum;
    }
  }
  
  pp_printf("Result: %x", sum);
  
  return sum;
}
