int main() {
  int i;
  int x = 6521;
  int y = 8991;
  for (i = 0; i < 24; ++i) {
    x *= y;
    ++y;
  }
  return x;
}
