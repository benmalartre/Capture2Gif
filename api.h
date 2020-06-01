#ifndef ANIMATEDGIF_API_H
#define ANIMATEDGIF_API_H
#include <cstdint>
#include <gif.h>

struct AnimatedGif_Writer {
  GifWriter* g;
  const char* filename;
  uint32_t width;
  uint32_t height;
  uint32_t delay;
};

#ifdef __cplusplus
extern "C" { 
#endif

extern AnimatedGif_Writer* AnimatedGif_Init(const char* filename, uint32_t width, uint32_t height, uint32_t delay);
extern void AnimatedGif_Term(AnimatedGif_Writer* writer);
extern void AnimatedGif_AddFrame(AnimatedGif_Writer* writer, void* datas);

#ifdef __cplusplus
}
#endif

#endif // ANIMATEDGIF_API_H