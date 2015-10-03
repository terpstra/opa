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
