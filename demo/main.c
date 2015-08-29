int buf[16];
const char name[] = "hello world";

int main() {
  int i;
  int x = 6521;
  int y = 8991;
  for (i = 0; i < 16; ++i) {
    x *= y;
    buf[i] = x;
  }
  return x;
}
