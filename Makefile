# Bullet makefile
SRC_DIR = "./"
DST_DIR = "./"

# Includes
INCLUDES = -I$(SRC_DIR)

# settings
#
CFLAGS = -DPLATFORM_DARWIN \
	 -DCC_GNU_ \
	 -DOSMac_ \
	 -DOSMacOSX_ \
	 -DOSMac_MachO_ \
	 -DPB_MACOS
	 -O3 \
	 -D_LANGUAGE_C_PLUS_PLUS\
	 -mmacosx-version-min=10.9\
	 -arch x86_64\
	 -fPIC\
	 -DNDEBUG\
	 -static

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

# iphone SDK
#CFLAGS += -arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS10.2.sdk

# Apple SDK
CFLAGS += -arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

LDFLAGS +=

# Rules
#./configure armv7 --build x86_64 --host=arm-apple-darwin10 --target=aarch64-apple-darwin #CC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang EXTRA_CFLAGS='-arch arm64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS10.2.sdk' EXTRA_LDFLAGS='-arch arm64'


all: api.o Gif.a

api.o: api.cpp api.h gif.h
	clang++ $(INCLUDES) -c $(C++FLAGS) -Wall	-mmacosx-version-min=10.7 -g api.cpp

Gif.a:  api.o
	ar rcs $@ $^

clean:
	rm -rf *.o *.gah *.a
