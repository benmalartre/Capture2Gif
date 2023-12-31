#ifndef ANIMATEDGIF_API_H
#define ANIMATEDGIF_API_H


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
AnimatedGif_Writer* AnimatedGif_Init(const char* filename, uint32_t width, uint32_t height, uint32_t delay);
void AnimatedGif_Term(AnimatedGif_Writer* writer);
void AnimatedGif_AddFrame(AnimatedGif_Writer* writer, void* datas);
#ifdef __cplusplus
}
#endif

#endif // ANIMATEDGIF_API_H