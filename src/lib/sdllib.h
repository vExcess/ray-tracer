#ifndef HEADER_FILE
#define HEADER_FILE

unsigned int getScreenRes();

int createWindow(const char* title, int x, int y, int w, int h, unsigned int options);

void destroyWindow();

void pollInput();

unsigned int millis();

void wait(unsigned int ms);

unsigned int getWindowRes();

unsigned int* getPixels();

void updateWindow();

#endif