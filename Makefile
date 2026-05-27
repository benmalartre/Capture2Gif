# Bullet makefile
SRC_DIR = "./"
DST_DIR = "./"

# Includes
INCLUDES = -I$(SRC_DIR)

# settings
#
SDK_PATH := $(shell xcrun --show-sdk-path)

CFLAGS = -DPLATFORM_DARWIN \
	 -DCC_GNU_ \
	 -DOSMac_ \
	 -DOSMacOSX_ \
	 -DOSMac_MachO_ \
	 -DPB_MACOS \
	 -O3 \
	 -D_LANGUAGE_C_PLUS_PLUS\
	 -mmacosx-version-min=10.9\
	 -fPIC\
	 -DNDEBUG\
	 -isysroot $(SDK_PATH)

C++FLAGS = $(CFLAGS) \
	-std=c++11 \
	-stdlib=libc++ \
	-fno-gnu-keywords \
	-fpascal-strings  \
	-Wno-deprecated \
	-Wpointer-arith \
	-Wwrite-strings \
	-Wno-long-long \
	-arch arm64

LDFLAGS +=

all: api.o Gif.a

api.o: api.cpp api.h gif.h
	clang++ $(INCLUDES) -c $(C++FLAGS) -Wall	-mmacosx-version-min=10.7 -g api.cpp

Gif.a:  api.o
	ar rcs $@ $^

clean:
	rm -rf *.o *.gah *.a
