#include <stdio.h>
#include <stdlib.h>

int main(int argc, const char **argv) {
  int ns = atol(argv[1]);
  int nw = atol(argv[2]);
  int ps = 1 << ns;
  int pw = 1 << nw;
  int s, w, x, sum, bs, bw;
  
  for (s = 0; s < ps; ++s) {
    for (w = 0; w < pw; ++w) {
      sum = s;
      for (x = w; x; x >>= 1) sum += (x&1);
      if (sum >= ps) sum = ps-1;
      
      printf("        \"");
      for (bs = 0; bs < ns; ++bs)
        printf("%d", (sum>>(ns-1-bs))&1);
      printf("\" when \"");
      for (bs = 0; bs < ns; ++bs)
        printf("%d", (s>>(ns-1-bs))&1);
      for (bw = 0; bw < nw; ++bw)
        printf("%d", (w>>(nw-1-bw))&1);
      printf("\",\n");
    }
  }
  printf("        \"");
  for (bs = 0; bs < ns; ++bs)
    printf("-");
  printf("\" when others;\n");
  
  return 0;
}
