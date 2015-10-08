#include <string.h>
#include <stdio.h>

#include "pp-printf.h"

/* If a square is known, it is filled with
 */
unsigned char sequence;
unsigned char mark[9][9];
unsigned char known[9][9];
unsigned char square[9][9][9];

void checkRow(int row)
{
  int col, opt;
  unsigned char seen[10], what;
  
  memset(seen, 0, sizeof(seen));
  for (col = 0; col < 9; ++col) {
    if (0 != (what = known[row][col])) {
      if (++seen[what] != 1) pp_printf("DUPLICATE IN ROW %d", row+1);
    }
  }
  
  // Eliminate all options
  for (col = 0; col < 9; ++col) {
    what = known[row][col];
    for (opt = 1; opt <= 9; ++opt) {
      if (opt == what) continue; // don't mark knowns invalid
      if (seen[opt]) { // eliminate candidates
        square[row][col][opt-1] = sequence;
      }
    }
  }
}

void checkCol(int col)
{
  int row, opt;
  unsigned char seen[10], what;
  
  memset(seen, 0, sizeof(seen));
  for (row = 0; row < 9; ++row) {
    if (0 != (what = known[row][col])) {
      if (++seen[what] != 1) pp_printf("DUPLICATE IN COLUMN %d", col+1);
    }
  }
  
  // Eliminate all options
  for (row = 0; row < 9; ++row) {
    what = known[row][col];
    for (opt = 1; opt <= 9; ++opt) {
      if (opt == what) continue; // don't mark knowns invalid
      if (seen[opt]) { // eliminate candidates
        square[row][col][opt-1] = sequence;
      }
    }
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
      if (0 != (what = known[row][col])) {
        if (++seen[what] != 1) pp_printf("DUPLICATE IN SQUARE %d,%d", r+1, c+1);
      }
    }
  }
  
  // Eliminate all options
  for (i = 0; i < 3; ++i) {
    for (j = 0; j < 3; ++j) {
      row = r*3 + i;
      col = c*3 + j;
      what = known[row][col];
      for (opt = 1; opt <= 9; ++opt) {
        if (opt == what) continue; // don't mark knowns invalid
        if (seen[opt]) { // eliminate candidates
          square[row][col][opt-1] = sequence;
        }
      }
    }
  }
}

int findKnown()
{
  int i, j, k, opts, last, found;
  
  found = 0;
  for (i = 0; i < 9; ++i) {
    for (j = 0; j < 9; ++j) {
      opts = 0;
      last = -1;
      for (k = 0; k < 9; ++k) {
        if (!square[i][j][k]) {
          ++opts;
          last = k;
        }
      }
      switch (opts) {
      case 0: pp_printf("IMPOSSIBLE PUZZLE"); break;
      case 1: 
        k = known[i][j];
        mark[i][j] = !k;
        found += !k;
        known[i][j] = last+1; 
        break;
      }
    }
  }
  
  return found;
}  

void printSquare()
{
  int row, col;
  char buf[120];
  char *x;
  
  for (row = 0; row < 9; ++row) {
    if (row == 3 || row == 6)
      pp_printf("-----------");
    
    x = &buf[0];
    for (col = 0; col < 9; ++col) {
      if (col == 3 || col == 6)
        *x++ = '|';
      
      if (known[row][col]) {
        if (mark[row][col]) {
          *x++ = 27;
          *x++ = '[';
          *x++ = '4';
          *x++ = '2';
          *x++ = 'm';
        }
        *x++ = known[row][col] + '0';
        if (mark[row][col]) {
          *x++ = 27;
          *x++ = '[';
          *x++ = '0';
          *x++ = 'm';
        }
      } else {
        *x++ = '.';
      }
    }
    *x = 0;
    pp_printf("%s", buf);
  }
  pp_printf("\n");
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
        sequence = 1;
        memset(square, 0, sizeof(square));
        solve();
      }
    }
  }
}
