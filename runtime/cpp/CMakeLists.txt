cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher 
  VERSION 0.0.19
  DESCRIPTION "The Fletcher runtime library"
  HOMEPAGE_URL "https://github.com/abs-tudelft/fletcher"
  LANGUAGES CXX
)

find_package(Arrow 4.0.1 CONFIG REQUIRED)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

set(TEST_PLATFORM_DEPS)
if(BUILD_TESTS)
  if(NOT TARGET fletcher::echo)
    add_subdirectory(../../platforms/echo/runtime echo)
  endif()
  list(APPEND TEST_PLATFORM_DEPS "fletcher::echo")
  if(UNIX AND NOT APPLE)
    list(APPEND TEST_PLATFORM_DEPS "-Wl,--disable-new-dtags")
  endif()
endif()

if(NOT TARGET fletcher::common)
  add_subdirectory(../../common/cpp common)
endif()
if(NOT TARGET fletcher::c)
  add_subdirectory(../../common/c c)
endif()

add_compile_unit(
  NAME fletcher
  TYPE SHARED
  COMPONENT library
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletcher/platform.cc
    src/fletcher/context.cc
    src/fletcher/kernel.cc
  DEPS
    fletcher::c
    fletcher::common
    arrow_shared
    ${CMAKE_DL_LIBS}
)

add_compile_unit(
  NAME fletcher::test
  TYPE TESTS
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    test/fletcher/test.cpp
  DEPS
    fletcher
    ${TEST_PLATFORM_DEPS}
)

compile_units()

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
set(CPACK_COMPONENTS_ALL library)
set(CPACK_PACKAGE_VENDOR "Accelerated Big Data Systems, Delft University of Technology")
set(CPACK_PACKAGE_DESCRIPTION "The Fletcher C++ runtime library for Fletcher-based applications")
set(CPACK_PACKAGE_VERSION_MAJOR "${fletcher_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${fletcher_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${fletcher_VERSION_PATCH}")
set(CPACK_PACKAGE_RELOCATABLE ON)

set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libarrow-dev (>= 3.0.0), libarrow-dev (<< 5.0.0)")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")

set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
set(CPACK_RPM_PACKAGE_DESCRIPTION "${CPACK_PACKAGE_DESCRIPTION}")
set(CPACK_RPM_PACKAGE_LICENSE "ASL 2.0")
# fletcher-devel
set(CPACK_RPM_PACKAGE_REQUIRES "arrow-devel >= 3.0.0, arrow-devel < 5.0.0")

set(CPACK_ARCHIVE_LIBRARY_FILE_NAME "${CMAKE_PROJECT_NAME}-${fletcher_VERSION}-${CMAKE_SYSTEM_NAME}")

include(CPack)
