short buf1[16] = { 0, -1,  2, -3,  4, -5,  6, -7,  8, -9,  10, -11, 12, -13,  14, -15 };
char  buf2[16] = { 0,  1, -2, -3,  4,  5, -6, -7,  8,  9, -10, -11, 12,  13, -14, -15 };
const char hello[] = "hello world\n";
char zeros[200];

volatile unsigned int* stdout = (unsigned int*)0x80000000U;

int main() {
  int sum = 0;
  int i, j;
  
  for (i = 0; i < sizeof(hello); ++i)
    *stdout = hello[i];
  
  for (j = 0; j < 2; ++j) {
    // first iteration should be full of cache misses. second should be a rocket.
    for (i = 0; i < 16; ++i) {
      sum += buf1[i] * buf2[i] + (buf2[i] << i);
      buf1[i] = sum;
    }
  }
  
  return sum;
}
