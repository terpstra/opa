void bb_open(int vendor, int device);
void bb_close();

void bb_reset();
void bb_shIR64(uint64_t ir,           int bits, int read = 0);
void bb_shIR(const unsigned char* dr, int bits, int read = 0);
void bb_shDR64(uint64_t dr,           int bits, int read = 0);
void bb_shDR(const unsigned char* dr, int bits, int read = 0);

std::vector<unsigned char> bb_execute();
uint64_t bb_execute64();
