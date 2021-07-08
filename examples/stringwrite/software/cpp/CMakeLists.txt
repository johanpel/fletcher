cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

include(FetchContent)
FetchContent_Declare(cmake-modules
    GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
    GIT_TAG         master
    )
FetchContent_MakeAvailable(cmake-modules)
include(CompileUnits)

project(stringwrite VERSION 0.0.0 LANGUAGES CXX)

find_package(Arrow 4.0 CONFIG REQUIRED)
find_package(fletcher CONFIG)

if (NOT fletcher)
    add_subdirectory(../../../../runtime/cpp fletcher)
endif()

add_compile_unit(
    NAME stringwrite
    TYPE EXECUTABLE
    PRPS
        CXX_STANDARD 11
        CXX_STANDARD_REQUIRED ON
    SRCS
        src/stringwrite.cpp
    DEPS
        arrow_shared
        fletcher
)

compile_units()
