#include "gif.h"
#include "api.h"



AnimatedGif_Writer* AnimatedGif_Init(const char* filename, uint32_t width, uint32_t height, uint32_t delay)
{
  AnimatedGif_Writer* writer = new AnimatedGif_Writer();
  writer->filename = filename;
  writer->width = width;
  writer->height = height;
  writer->delay = delay;
  GifBegin(writer->g, writer->filename, writer->width, writer->height, writer->delay);
  return writer;
}

void AnimatedGif_Term(AnimatedGif_Writer* writer)
{
  GifEnd(writer->g);
  delete writer;
}

void AnimatedGif_AddFrame(AnimatedGif_Writer* writer, void* datas)
{
  GifWriteFrame(writer->g, (uint8_t*)datas, writer->width, writer->height, writer->delay);
}