cmake_minimum_required(VERSION 3.6)
project(Gif)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CONFIGURATION_TYPES "Release" CACHE STRING "" FORCE)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(CMAKE_CXX_FLAGS_RELEASE "/GS- /MT /D_CRT_SECURE_NO_WARNINGS" )
endif()

set(SOURCE_FILES api.cpp api.h gif.h)
add_library(Gif STATIC ${SOURCE_FILES})