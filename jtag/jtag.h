/*  opa: Open Processor Architecture
 *  Copyright (C) 2014-2016  Wesley W. Terpstra
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

void bb_open(int vendor = 0x9fb, int device = 0x6001);
void bb_close();

void bb_reset();
void bb_shIR64(uint64_t ir,           int bits, int read = 0);
void bb_shIR(const unsigned char* dr, int bits, int read = 0);
void bb_shDR64(uint64_t dr,           int bits, int read = 0);
void bb_shDR(const unsigned char* dr, int bits, int read = 0);

std::vector<unsigned char> bb_execute();
uint64_t bb_execute64();

// If BYTE_STB is set in input, the byte is sent to the CPU
#define BYTE_STB 0x100
void opa_uart(uint32_t byte);

void opa_read(uint64_t address);
void opa_write(uint64_t address, uint64_t value, int old = 0);
void opa_gpio(uint8_t dat);
void opa_probe(int loader_id = 99, int uart_id = 98);
