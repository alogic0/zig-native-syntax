add_library(native STATIC src/native.cpp)
target_include_directories(native PUBLIC include)
set(NATIVE_MODE "release")

if(BUILD_TESTING)
  add_executable(native_test tests/native_test.cpp)
  add_test(NAME native_test COMMAND native_test)
endif()
