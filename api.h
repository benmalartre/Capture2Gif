#ifndef ANIMATEDGIF_API_H
#define ANIMATEDGIF_API_H

#include <stdint.h>

struct GifWriter;

struct AnimatedGif_Writer {
  GifWriter* g;
  const char* filename;
  uint32_t width;
  uint32_t height;
  uint32_t delay;

  AnimatedGif_Writer() : g(new GifWriter()),filename(""),width(0),height(0),delay(0){};
  ~AnimatedGif_Writer() { delete g; };
};

#ifdef __cplusplus
extern "C" {
#endif

// --- Original streaming API (kept for compatibility) ---
AnimatedGif_Writer* AnimatedGif_Init(const char* filename, uint32_t width, uint32_t height, uint32_t delay);
void AnimatedGif_Term(AnimatedGif_Writer* writer);
void AnimatedGif_AddFrame(AnimatedGif_Writer* writer, void* datas);

// --- Frame buffer management ---
// Allocate an RGBA frame buffer (width * height * 4 bytes)
void* AnimatedGif_AllocFrame(int width, int height);
// Free a frame buffer allocated with AnimatedGif_AllocFrame
void  AnimatedGif_FreeFrame(void* frame);

// --- Batch export: write a subset of stored frames to a GIF file ---
// frames: array of RGBA frame pointers (each width*height*4 bytes)
// start/end: inclusive frame indices to export
// delay: centiseconds per frame (e.g. 5 = 50ms, 10 = 100ms)
void AnimatedGif_WriteFrames(const char* filename, void** frames, int count,
                              int width, int height,
                              int start, int end, int delay);

// --- GIF loading: decode an animated GIF into raw RGBA frames ---
// Returns a malloc'd array of malloc'd RGBA buffers (one per frame).
// out_count: number of frames decoded
// out_width / out_height: frame dimensions
// out_delay: delay of the first frame in centiseconds (from GIF metadata)
// Returns NULL on failure. Caller must free with GifFreeFrames().
void** GifLoad(const char* filename, int* out_count,
               int* out_width, int* out_height, int* out_delay);

// Free the frame array returned by GifLoad
void GifFreeFrames(void** frames, int count);

#ifdef __cplusplus
}
#endif

#endif // ANIMATEDGIF_API_H
