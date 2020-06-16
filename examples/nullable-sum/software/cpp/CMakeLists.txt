cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

include(FetchContent)
FetchContent_Declare(cmake-modules
    GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
    GIT_TAG         master
    )
FetchContent_MakeAvailable(cmake-modules)
include(CompileUnits)


project(sum VERSION 0.0.0 LANGUAGES CXX)

find_package(arrow 0.15 CONFIG REQUIRED)
find_package(fletcher CONFIG)

if (NOT fletcher)
  add_subdirectory(../../../../runtime/cpp fletcher)
endif()

add_compile_unit(
    NAME sum
    TYPE EXECUTABLE
    PRPS
      CXX_STANDARD 11
      CXX_STANDARD_REQUIRED ON
    SRCS
      src/sum.cpp
    DEPS
      arrow_shared
      fletcher
)

compile_units()
