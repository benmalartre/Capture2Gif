# Capture2Gif
Screen Capture Gif Creator (windows only)

Animated Gif Library from https://github.com/charlietangora/gif-h


# Build on windows
```
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..\
msbuild Gif.sln
copy /Y Release\Gif.lib ..\Gif.lib
```