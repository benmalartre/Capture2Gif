cmake_minimum_required(VERSION 3.6)
project(Gif)

set(CMAKE_CXX_STANDARD 14)

set(SOURCE_FILES api.cpp api.h gif.h)
add_library(Gif STATIC ${SOURCE_FILES})