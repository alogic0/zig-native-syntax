# CMake lexical corpus
cmake_minimum_required(VERSION 3.28)
project(Demo)
set(NAME "demo\n<&>")
if(ON)
  add_executable(app main.cpp)
endif()
