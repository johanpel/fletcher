cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletchgen
  VERSION 0.0.19
  DESCRIPTION "The Fletcher design generator"
  HOMEPAGE_URL "https://github.com/abs-tudelft/fletcher"
  LANGUAGES CXX
)

find_package(Arrow 4.0.1 CONFIG REQUIRED)

include(FindThreads)
include(FetchContent)

FetchContent_Declare(CLI11
  GIT_REPOSITORY  https://github.com/CLIUtils/CLI11.git
  GIT_TAG         v1.8.0
)
FetchContent_MakeAvailable(CLI11)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

FetchContent_Declare(cerata
    GIT_REPOSITORY  https://github.com/abs-tudelft/cerata.git
    GIT_TAG         0.0.11
)
FetchContent_GetProperties(cerata)
if(NOT cerata_POPULATED)
  FetchContent_Populate(cerata)
  set(BUILD_CERATA_TESTS OFF CACHE BOOL "")
  set(BUILD_CERATA_DOT ON CACHE BOOL "")
  set(BUILD_CERATA_VHDL ON CACHE BOOL "")
  set(BUILD_CERATA_YAML ON CACHE BOOL "")
  add_subdirectory(${cerata_SOURCE_DIR} ${cerata_BINARY_DIR} EXCLUDE_FROM_ALL)
  # https://gitlab.kitware.com/cmake/cmake/-/issues/20212
  add_custom_target(exclude_cerata_tests ALL COMMAND rm -f "${cerata_BINARY_DIR}/CTestTestfile.cmake")
endif()

include(CompileUnits)

if(NOT TARGET fletcher::common)
  add_subdirectory(../../../common/cpp common-cpp EXCLUDE_FROM_ALL)
  # https://gitlab.kitware.com/cmake/cmake/-/issues/20212
  add_custom_target(exclude_fletcher_common_tests ALL COMMAND rm -f "common-cpp/CTestTestfile.cmake")
endif()
if(NOT TARGET fletcher::c)
  add_subdirectory(../../../common/c common-c EXCLUDE_FROM_ALL)
  # https://gitlab.kitware.com/cmake/cmake/-/issues/20212
  add_custom_target(exclude_fletcher_common_c_tests ALL COMMAND rm -f "common-c/CTestTestfile.cmake")
endif()

FetchContent_Declare(cmakerc
  GIT_REPOSITORY  https://github.com/vector-of-bool/cmrc.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmakerc)

file(
    GLOB_RECURSE RESOURCE_FILES
    LIST_DIRECTORIES false
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../hardware/**/*"
)
cmrc_add_resource_library(
    fletchgen-resources
    ALIAS fletchgen::resources
    NAMESPACE fletchgen
    WHENCE "${CMAKE_CURRENT_SOURCE_DIR}/../../.."
    ${RESOURCE_FILES}
)
set_property(
    TARGET fletchgen-resources
    PROPERTY POSITION_INDEPENDENT_CODE ON
)

add_compile_unit(
  OPT
  NAME fletchgen::obj
  TYPE OBJECT
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletchgen/schema.cc
    src/fletchgen/bus.cc
    src/fletchgen/mmio.cc
    src/fletchgen/array.cc
    src/fletchgen/basic_types.cc
    src/fletchgen/mantle.cc
    src/fletchgen/kernel.cc
    src/fletchgen/options.cc
    src/fletchgen/design.cc
    src/fletchgen/utils.cc
    src/fletchgen/recordbatch.cc
    src/fletchgen/fletchgen.cc
    src/fletchgen/nucleus.cc
    src/fletchgen/profiler.cc
    src/fletchgen/axi4_lite.cc
    src/fletchgen/external.cc
    src/fletchgen/static_vhdl.cc

    src/fletchgen/srec/recordbatch.cc
    src/fletchgen/srec/srec.cc

    src/fletchgen/top/sim.cc
    src/fletchgen/top/axi.cc

    src/fletchgen/hls/vivado.cc
  TSTS
    test/fletchgen/test_array.cc
    test/fletchgen/test_bus.cc
    test/fletchgen/test_kernel.cc
    test/fletchgen/test_nucleus.cc
    test/fletchgen/test_mantle.cc
    test/fletchgen/test_misc.cc
    test/fletchgen/test_recordbatch.cc
    test/fletchgen/test_types.cc
    test/fletchgen/test_profiler.cc
    test/fletchgen/srec/test_srec.cc
  DEPS
    cerata
    arrow_shared
    fletcher::common
    fletcher::c
    CLI11::CLI11
    Threads::Threads
    fletchgen::resources
)

add_compile_unit(
  OPT
  NAME fletchgen::lib
  TYPE SHARED
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  DEPS
    fletchgen::obj
)

add_compile_unit(
  NAME fletchgen
  TYPE EXECUTABLE
  COMPONENT binary
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletchgen/main.cc
  DEPS
    fletchgen::obj
)

compile_units()

configure_file(src/fletchgen/config.h.in fletchgen_config/config.h)
include_directories(${PROJECT_BINARY_DIR})

execute_process (
    COMMAND bash -c "awk -F= '/^ID=/{print $2}' /etc/os-release |tr -d '\n' | tr -d '\"'"
    OUTPUT_VARIABLE OS_NAME
)

execute_process (
    COMMAND bash -c "awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release |tr -d '\n' | tr -d '\"'"
    OUTPUT_VARIABLE OS_VERSION
)

if(OS_NAME MATCHES "ubuntu")
  set(CPACK_DEBIAN_PACKAGE_RELEASE "ubuntu${OS_VERSION}")
  set(CPACK_GENERATOR "DEB")
elseif(OS_NAME MATCHES "centos")
  set(CPACK_RPM_PACKAGE_RELEASE_DIST "el${OS_VERSION}")
  if(OS_VERSION MATCHES "7")
    set(CPACK_GENERATOR "RPM;TGZ")
  else()
    set(CPACK_GENERATOR "RPM")
  endif()
endif()

set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
set(CPACK_COMPONENTS_ALL binary)
set(CPACK_PACKAGE_VENDOR "Accelerated Big Data Systems, Delft University of Technology")
set(CPACK_PACKAGE_DESCRIPTION "The Fletcher design generator")
set(CPACK_PACKAGE_VERSION_MAJOR "${fletchgen_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${fletchgen_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${fletchgen_VERSION_PATCH}")
set(CPACK_PACKAGE_RELOCATABLE ON)

set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libarrow400")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")

set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
set(CPACK_RPM_PACKAGE_DESCRIPTION "${CPACK_PACKAGE_DESCRIPTION}")
set(CPACK_RPM_PACKAGE_LICENSE "ASL 2.0")
set(CPACK_RPM_PACKAGE_REQUIRES "arrow-libs >= 3.0.0, arrow-libs < 5.0.0")

set(CPACK_ARCHIVE_BINARY_FILE_NAME "${CMAKE_PROJECT_NAME}-${fletchgen_VERSION}-${CMAKE_SYSTEM_NAME}")

include(CPack)
