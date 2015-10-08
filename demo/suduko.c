// #define DEBUG 1

#include <string.h>
#include <stdio.h>

#include "pp-printf.h"

unsigned char mark[9][9];
unsigned char known[9][9];
unsigned char square[9][9][9];

void checkRow(int row)
{
  int col, opt;
  unsigned char seen[10], what;
  
  memset(seen, 0, sizeof(seen));
  for (col = 0; col < 9; ++col) {
    what = known[row][col];
#if DEBUG
    if (seen[what]) puts("DUPLICATE IN ROW");
#endif
    seen[what] = 1;
  }
  
  // Eliminate all options
  for (col = 0; col < 9; ++col) {
    what = known[row][col];
    for (opt = 1; opt <= 9; ++opt)
      square[row][col][opt-1] |= (opt != what) & seen[opt];
  }
}

void checkCol(int col)
{
  int row, opt;
  unsigned char seen[10], what;
  
  memset(seen, 0, sizeof(seen));
  for (row = 0; row < 9; ++row) {
    what = known[row][col];
#if DEBUG
    if (seen[what]) puts("DUPLICATE IN COL");
#endif
    seen[what] = 1;
  }
  
  // Eliminate all options
  for (row = 0; row < 9; ++row) {
    what = known[row][col];
    for (opt = 1; opt <= 9; ++opt)
      square[row][col][opt-1] |= (opt != what) & seen[opt];
  }
}

void checkSquare(int r, int c)
{
  int i, j, row, col, opt;
  unsigned char seen[10], what;
  
  memset(seen, 0, sizeof(seen));
  for (i = 0; i < 3; ++i) {
    for (j = 0; j < 3; ++j) {
      row = r*3 + i;
      col = c*3 + j;
      what = known[row][col];
#if DEBUG
      if (seen[what]) puts("DUPLICATE IN SQUARE");
#endif
      seen[what] = 1;
    }
  }
  
  // Eliminate all options
  for (i = 0; i < 3; ++i) {
    for (j = 0; j < 3; ++j) {
      row = r*3 + i;
      col = c*3 + j;
      what = known[row][col];
      for (opt = 1; opt <= 9; ++opt)
        square[row][col][opt-1] |= (opt != what) & seen[opt];
    }
  }
}

int findKnown()
{
  int i, j, k, opts, last, found, now, old;
  
  found = 0;
  for (i = 0; i < 9; ++i) {
    for (j = 0; j < 9; ++j) {
      opts = 0;
      last = 0;
      for (k = 0; k < 9; ++k) {
        int possible = !square[i][j][k];
        opts += possible;
        last += k*possible;
      }
#if DEBUG
      if (opts == 0) puts("IMPOSSIBLE PUZZLE");
#endif
      old = known[i][j];
      now = (opts == 1) && !old;
      mark[i][j] = now;
      found += now;
      known[i][j] = old + now * (last+1);
    }
  }
  
  return found;
}  

void printSquare()
{
  int row, col, green;
  char buf[120];
  char *x;
  
  puts("\n");
  for (row = 0; row < 9; ++row) {
    if (row == 3 || row == 6)
      puts("-----------");
    
    x = &buf[0];
    for (col = 0; col < 9; ++col) {
      *x = '|';
      x += (col == 3 || col == 6);
      
      green = mark[row][col];
      *x = 27;  x += green;
      *x = '['; x += green;
      *x = '4'; x += green;
      *x = '2'; x += green;
      *x = 'm'; x += green;
      *x++ = (known[row][col] + '0') - (known[row][col] == 0) * ('0' - '.');
      *x = 27;  x += green;
      *x = '['; x += green;
      *x = '0'; x += green;
      *x = 'm'; x += green;
    }
    *x = 0;
    puts(buf);
  }
}

void solve()
{
  memset(mark, 0, sizeof(mark));
  
  do {
    int i, j;
    
    // Show progress
    printSquare();
    
    // Check if we know something on a row
    for (i = 0; i < 9; ++i) checkRow(i);
    
    // Check if we know something on a col
    for (i = 0; i < 9; ++i) checkCol(i);
    
    // Eliminate cases for a square
    for (i = 0; i < 3; ++i)
      for (j = 0; j < 3; ++j)
        checkSquare(i, j);
    
    // Find which squares became known
    memset(mark, 0, sizeof(mark));
  } while (findKnown() > 0);
}

void suduko() {
  int row = 0, col = 0;
  int c;
  
  while (1) {
    c = my_getchar();
    
    if (c == 'r') { // reset
      row = col = 0;
      continue;
    }
    
    if (c != '.' && (c < '1' || c > '9')) { // not a board character
      continue;
    }
    
    // fill in the board
    if (c == '.') {
      known[row][col] = 0;
    } else {
      known[row][col] = c - '0';
    }
    
    if (++col == 9) {
      col = 0;
      if (++row == 9) {
        row = 0;
        memset(square, 0, sizeof(square));
        solve();
      }
    }
  }
}
