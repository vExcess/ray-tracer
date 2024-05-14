#include <stdio.h>
#include <SDL2/SDL.h>
#include "sdllib.h"

SDL_Window* window = NULL;

#define ERROR 0
#define SUCCESS 1
#define false 0
#define true 1

extern int handleSDLEvent(int eventType, int eventData);

unsigned int getScreenRes() {
    SDL_DisplayMode dm;

    if (SDL_GetDesktopDisplayMode(0, &dm) != 0) {
        SDL_Log("SDL_GetDesktopDisplayMode failed: %s", SDL_GetError());
        return ERROR;
    }

    // bitmask width and height together
    return dm.w << 16 | dm.h;
}

int createWindow(const char* title, int x, int y, int w, int h, unsigned int options) {
    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        fprintf(stderr, "Err init SDL");
        return ERROR;
    }

    window = SDL_CreateWindow(
        title, // title string/NULL
        x, // x
        y, // y
        w, // w
        h, // height
        options
    );

    if (!window) {
        fprintf(stderr, "Err create SDL window");
        return ERROR;
    }

    return SUCCESS; // ok
}

void destroyWindow() {
    SDL_DestroyWindow(window);
    SDL_Quit();
}

void pollInput() {
    SDL_Event event;
    SDL_PollEvent(&event);

    int eventType = event.type;
    int eventData = 0;

    if (event.type == SDL_KEYDOWN) {
        eventData = event.key.keysym.sym;
    }

    handleSDLEvent(eventType, eventData);
}

unsigned int millis() {
    return SDL_GetTicks();
}

void wait(unsigned int ms) {
    SDL_Delay(ms);
}

unsigned int getWindowRes() {
    SDL_Surface * window_surface = SDL_GetWindowSurface(window);
    // bitmask width and height together
    return window_surface->w << 16 | window_surface->h;
}
 
unsigned int* getPixels() {
    SDL_Surface * window_surface = SDL_GetWindowSurface(window);
    return window_surface->pixels;
}

void updateWindow() {
    SDL_UpdateWindowSurface(window);
}

