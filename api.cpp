#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include "gif.h"
#include "api.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// --- Original streaming API ---

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

// --- Frame buffer management ---

void* AnimatedGif_AllocFrame(int width, int height)
{
  return malloc((size_t)width * height * 4);
}

void AnimatedGif_FreeFrame(void* frame)
{
  free(frame);
}

// --- Batch export ---

void AnimatedGif_WriteFrames(const char* filename, void** frames, int count,
                              int width, int height,
                              int start, int end, int delay)
{
  if (!frames || count <= 0 || start < 0 || end >= count || start > end)
    return;

  GifWriter g = {};
  GifBegin(&g, filename, (uint32_t)width, (uint32_t)height, (uint32_t)delay);
  for (int i = start; i <= end; i++) {
    if (frames[i])
      GifWriteFrame(&g, (uint8_t*)frames[i], (uint32_t)width, (uint32_t)height, (uint32_t)delay);
  }
  GifEnd(&g);
}

// --- GIF loading via stb_image ---

void** GifLoad(const char* filename, int* out_count,
               int* out_width, int* out_height, int* out_delay)
{
  *out_count  = 0;
  *out_width  = 0;
  *out_height = 0;
  *out_delay  = 5; // default 50ms

  FILE* f = fopen(filename, "rb");
  if (!f) return NULL;

  fseek(f, 0, SEEK_END);
  long fileSize = ftell(f);
  fseek(f, 0, SEEK_SET);

  unsigned char* fileData = (unsigned char*)malloc(fileSize);
  if (!fileData) { fclose(f); return NULL; }
  fread(fileData, 1, fileSize, f);
  fclose(f);

  int* delays = NULL;
  int width = 0, height = 0, channels = 0, frameCount = 0;

  // stbi_load_gif_from_memory returns all frames stacked vertically
  unsigned char* pixelData = stbi_load_gif_from_memory(
    fileData, (int)fileSize,
    &delays,
    &width, &height, &frameCount,
    &channels, 4 // force RGBA
  );
  free(fileData);

  if (!pixelData || frameCount <= 0) {
    if (pixelData) stbi_image_free(pixelData);
    if (delays) free(delays);
    return NULL;
  }

  *out_width  = width;
  *out_height = height;
  *out_count  = frameCount;
  // stb returns delays in milliseconds; convert to centiseconds for gif.h
  if (delays && delays[0] > 0)
    *out_delay = delays[0] / 10;

  size_t frameBytes = (size_t)width * height * 4;
  void** frames = (void**)malloc(sizeof(void*) * frameCount);
  if (!frames) {
    stbi_image_free(pixelData);
    if (delays) free(delays);
    return NULL;
  }

  for (int i = 0; i < frameCount; i++) {
    frames[i] = malloc(frameBytes);
    if (frames[i])
      memcpy(frames[i], pixelData + i * frameBytes, frameBytes);
  }

  stbi_image_free(pixelData);
  if (delays) free(delays);

  return frames;
}

void GifFreeFrames(void** frames, int count)
{
  if (!frames) return;
  for (int i = 0; i < count; i++)
    free(frames[i]);
  free(frames);
}
