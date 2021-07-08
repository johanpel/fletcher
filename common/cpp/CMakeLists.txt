cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_common VERSION 0.0.0 LANGUAGES CXX)

find_package(Arrow 4.0.1 CONFIG REQUIRED)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

add_compile_unit(
  NAME fletcher::common
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletcher/arrow-recordbatch.cc
    src/fletcher/arrow-schema.cc
    src/fletcher/arrow-utils.cc
    src/fletcher/hex-view.cc
  TSTS
    test/fletcher/test_common.cc
    test/fletcher/test_visitors.cc
  DEPS
    arrow_shared
)

add_compile_unit(
    OPT
    NAME fletcher::test_generate
    TYPE EXECUTABLE
    PRPS
      CXX_STANDARD 11
      CXX_STANDARD_REQUIRED ON
    SRCS
      test/fletcher/test_generate.cc
    DEPS
      fletcher::common
      arrow_shared
)

compile_units()
