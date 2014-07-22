#include <stdio.h>
#include <stdlib.h>

int main(int argc, const char **argv) {
  int ns = atol(argv[1]);
  int nw = atol(argv[2]);
  int ps = 1 << ns;
  int si, sum, bs;
  int acc[10];
  
  for (si = 0; si < nw; ++si)
    acc[si] = 0;
  
  while (1) {
    sum = 0;
    for (si = 0; si < nw; ++si)
      sum += acc[si];
    if (sum >= ps) sum = ps-1;
    
    printf("        \"");
    for (bs = 0; bs < ns; ++bs)
      printf("%d", (sum>>(ns-1-bs))&1);
    printf("\" when \"");
    for (si = 0; si < nw; ++si) {
      for (bs = 0; bs < ns; ++bs)
      printf("%d", (acc[nw-1-si]>>(ns-1-bs))&1);
    }
    printf("\",\n");
  
    for (si = 0; si < nw; ++si) {
      if (acc[si] != ps-1)
        break;
      acc[si] = 0;
    }
    if (si == nw) break;
    ++acc[si];
  }
  
  printf("        \"");
  for (bs = 0; bs < ns; ++bs)
    printf("-");
  printf("\" when others;\n");
  
  return 0;
}
