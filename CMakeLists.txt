cmake_minimum_required(VERSION 3.16)
project(Gif)

set(CMAKE_CXX_STANDARD 11)

add_library(Gif STATIC api.cpp api.h gif.h)
target_include_directories(Gif PRIVATE .)

if(APPLE)
  set(CMAKE_OSX_ARCHITECTURES "arm64")
  execute_process(COMMAND xcrun --show-sdk-path
    OUTPUT_VARIABLE MACOS_SDK_PATH OUTPUT_STRIP_TRAILING_WHITESPACE)
  target_compile_options(Gif PRIVATE
    -O3 -fPIC -stdlib=libc++ -fpascal-strings
    -mmacosx-version-min=10.9 -DPLATFORM_DARWIN -DNDEBUG
    -isysroot ${MACOS_SDK_PATH}
  )
  set_target_properties(Gif PROPERTIES OUTPUT_NAME "Gif" SUFFIX ".a" PREFIX "")
  set(LIB_DEST "${CMAKE_SOURCE_DIR}/Gif.a")
elseif(WIN32)
  set(CMAKE_CONFIGURATION_TYPES "Release" CACHE STRING "" FORCE)
  target_compile_options(Gif PRIVATE /O2 /GS- /MT /D_CRT_SECURE_NO_WARNINGS)
  set_target_properties(Gif PROPERTIES OUTPUT_NAME "Gif" SUFFIX ".lib")
  set(LIB_DEST "${CMAKE_SOURCE_DIR}/Gif.lib")
endif()

# Automatically copy the built library to the project root after each build
add_custom_command(TARGET Gif POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:Gif> "${LIB_DEST}"
  COMMENT "Copying Gif library to project root"
)

# --- PureBasic application ---
if(APPLE)
  set(PB_COMPILER "/Applications/PureBasic.app/Contents/Resources/compilers/pbcompiler"
      CACHE FILEPATH "Path to PureBasic command-line compiler")
  set(PB_APP_OUT "${CMAKE_SOURCE_DIR}/Capture2Gif")
elseif(WIN32)
  set(PB_COMPILER "C:/Program Files/PureBasic/compilers/pbcompiler.exe"
      CACHE FILEPATH "Path to PureBasic command-line compiler")
  set(PB_APP_OUT "${CMAKE_SOURCE_DIR}/Capture2Gif.exe")
endif()

if(EXISTS "${PB_COMPILER}")
  # PureBasic needs to run from its own Resources directory to locate its
  # resident files and OS libraries. Derive that from the compiler path:
  #   .../PureBasic.app/Contents/Resources/compilers/pbcompiler
  #                                         ^^^^^^^^^^ two levels up
  get_filename_component(PB_RESOURCES_DIR "${PB_COMPILER}" DIRECTORY)   # .../compilers
  get_filename_component(PB_RESOURCES_DIR "${PB_RESOURCES_DIR}" DIRECTORY) # .../Resources

  add_custom_target(App ALL
    COMMAND ${CMAKE_COMMAND} -E env PUREBASIC_HOME=${PB_RESOURCES_DIR}
            "${PB_COMPILER}" "${CMAKE_SOURCE_DIR}/App.pbi"
            --output "${PB_APP_OUT}"
            --thread
            --optimizer
    DEPENDS Gif
    WORKING_DIRECTORY "${PB_RESOURCES_DIR}"
    COMMENT "Compiling PureBasic App.pbi -> Capture2Gif"
  )

  if(APPLE)
    # Wrap the binary in a .app bundle with a stable bundle ID so macOS TCC
    # identifies the app by com.benmalartre.capture2gif across rebuilds.
    set(PB_APP_BUNDLE "${CMAKE_SOURCE_DIR}/Capture2Gif.app")
    add_custom_command(TARGET App POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory "${PB_APP_BUNDLE}/Contents/MacOS"
      COMMAND ${CMAKE_COMMAND} -E copy "${PB_APP_OUT}" "${PB_APP_BUNDLE}/Contents/MacOS/Capture2Gif"
      COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_SOURCE_DIR}/Info.plist" "${PB_APP_BUNDLE}/Contents/Info.plist"
      COMMAND codesign --force --sign - "${PB_APP_BUNDLE}"
      COMMENT "Packaging Capture2Gif.app and signing"
    )
  endif()
else()
  message(WARNING "PureBasic compiler not found at: ${PB_COMPILER}\nSet -DPB_COMPILER=<path> to enable app compilation.")
endif()
