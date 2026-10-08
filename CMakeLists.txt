cmake_minimum_required(VERSION 3.21)

file(READ VERSION _ver)
string(STRIP "${_ver}" _ver)
project(icey-server VERSION ${_ver} LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(ICEY_SOURCE_DIR "" CACHE PATH
  "Optional path to an icey source checkout for development builds")
set(ICEY_WEB_DIST_DIR "${PROJECT_SOURCE_DIR}/web/dist" CACHE PATH
  "Optional path to a built web UI dist directory for install packaging")

if(ICEY_SOURCE_DIR)
  if(NOT EXISTS "${ICEY_SOURCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "ICEY_SOURCE_DIR does not point to an icey source tree: ${ICEY_SOURCE_DIR}")
  endif()

  set(BUILD_APPLICATIONS OFF CACHE BOOL "" FORCE)
  set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
  set(BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
  set(BUILD_PERF OFF CACHE BOOL "" FORCE)
  set(WITH_OPENSSL ON CACHE BOOL "" FORCE)
  set(WITH_FFMPEG ON CACHE BOOL "" FORCE)
  set(WITH_LIBDATACHANNEL ON CACHE BOOL "" FORCE)

  add_subdirectory("${ICEY_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/_deps/icey")
else()
  find_package(icey REQUIRED COMPONENTS
    base crypto net http json symple av speech stun turn vision webrtc webrtc_support)
endif()

add_subdirectory(src/server)

install(FILES "${PROJECT_SOURCE_DIR}/packaging/config.example.json"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/icey-server"
  COMPONENT apps)

install(FILES "${PROJECT_SOURCE_DIR}/packaging/config.rtsp.example.json"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/icey-server"
  COMPONENT apps)

install(FILES
  "${PROJECT_SOURCE_DIR}/README.md"
  "${PROJECT_SOURCE_DIR}/LICENSE.md"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/doc/icey-server"
  COMPONENT apps)

install(DIRECTORY "${ICEY_WEB_DIST_DIR}/"
  DESTINATION "${CMAKE_INSTALL_DATADIR}/icey-server/web"
  COMPONENT apps
  OPTIONAL)
