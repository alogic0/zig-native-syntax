#[=[ CMake structural corpus ]=]
cmake_minimum_required(VERSION 3.28)
project(Demo)
set(NAME "demo\n<&>")
set(HOME_DIR "$ENV{HOME}")
set(CACHE_VALUE "$CACHE{CMAKE_BUILD_TYPE}")
set(BRACKET_VALUE [=[literal # text]=])

function(build_target source)
  add_executable(app ${source})
  set_property(TARGET app PROPERTY CXX_STANDARD 23)
  target_compile_definitions(app PRIVATE "$<$<CONFIG:Debug>:DEBUG_BUILD>")
endfunction()

macro(enable_warnings target)
  target_compile_options(app PRIVATE -Wall)
endmacro()

if(ON)
  build_target(app main.cpp)
endif()
