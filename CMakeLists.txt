cmake_minimum_required(VERSION 3.5)

project(v8)
include(ExternalProject)
include(ProcessorCount)

ProcessorCount(N)

set(V8_VERSION 6.7.0)
set(LIB_V8             "${CMAKE_SHARED_LIBRARY_PREFIX}v8${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(LIB_V8_LIBBASE     "${CMAKE_SHARED_LIBRARY_PREFIX}v8_libbase${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(LIB_V8_LIBPLATFORM "${CMAKE_SHARED_LIBRARY_PREFIX}v8_libplatform${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(LIB_ICU_COMMON     "${CMAKE_SHARED_LIBRARY_PREFIX}icuuc${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(LIB_ICU_I18N       "${CMAKE_SHARED_LIBRARY_PREFIX}icui18n${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(ICU_DATA           "icudtl.dat")

set(_EXTERNAL_PATH /tmp)

ExternalProject_add(depot_tools
    PREFIX ${_EXTERNAL_PATH}/depot_tools
    GIT_REPOSITORY https://chromium.googlesource.com/chromium/tools/depot_tools.git
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    BUILD_IN_SOURCE 1
)

if(NOT EXISTS ${_EXTERNAL_PATH}/depot_tools)
    ExternalProject_Add_Step(depot_tools v8_fetch
        COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools:$ENV{PATH} fetch --no-history v8
        WORKING_DIRECTORY ${_EXTERNAL_PATH}
        DEPENDEES install
        COMMENT "Fetching v8..."
    )

    ExternalProject_Add_Step(depot_tools v8_gclient
        COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools/$ENV{PATH} gclient sync
        DEPENDEES v8_fetch
        WORKING_DIRECTORY ${_EXTERNAL_PATH}/v8
        COMMENT "gclient sync..."
    )
else()
    ExternalProject_Add_Step(depot_tools v8_gclient
        COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools/$ENV{PATH} gclient sync
        WORKING_DIRECTORY ${_EXTERNAL_PATH}/v8
        COMMENT "gclient sync..."
    )
endif()

if(CMAKE_HOST_SYSTEM_NAME MATCHES LINUX)
    ExternalProject_Add_Step(depot_tools v8_install_build_deps
        COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools:$ENV{PATH} ./build/install-build-deps.sh
        DEPENDEES v8_gclient
        WORKING_DIRECTORY ${_EXTERNAL_PATH}/v8
        COMMENT "building v8 deps..."
    )

    ExternalProject_Add_Step(depot_tools v8_generate
        COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools:$ENV{PATH} ${PROJECT_SOURCE_DIR}/generate-v8.sh
        DEPENDEES v8_install_build_deps
        WORKING_DIRECTORY ${_EXTERNAL_PATH}/v8
        COMMENT "generating v8 ninja build system..."
    )
else()

    ExternalProject_Add_Step(depot_tools v8_generate
        COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools:$ENV{PATH} ${PROJECT_SOURCE_DIR}/generate-v8.sh
        DEPENDEES v8_gclient
        WORKING_DIRECTORY ${_EXTERNAL_PATH}/v8
        COMMENT "generating v8 ninja build system..."
    )

endif()


ExternalProject_Add_Step(depot_tools v8_build
    COMMAND ${CMAKE_COMMAND} -E env PATH=${_EXTERNAL_PATH}/depot_tools/src/depot_tools:$ENV{PATH} ninja -C out.gn/x64.release
    DEPENDEES v8_generate
    WORKING_DIRECTORY ${_EXTERNAL_PATH}/v8
    COMMENT "building v8..."

    BYPRODUCTS
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8_LIBBASE}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8_LIBPLATFORM}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_ICU_COMMON}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_ICU_I18N}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${ICU_DATA}
)

set(INSTALL_DIR ${_EXTERNAL_PATH}/v8/out.gn/x64.release)
set(ConfigPackageLocation lib/cmake/v8)

add_library(v8 INTERFACE)
target_link_libraries(v8 INTERFACE
    $<BUILD_INTERFACE:${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8}>
    $<BUILD_INTERFACE:${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8_LIBBASE}>
    $<BUILD_INTERFACE:${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8_LIBPLATFORM}>
    $<BUILD_INTERFACE:${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_ICU_COMMON}>
    $<BUILD_INTERFACE:${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_ICU_I18N}>
    $<INSTALL_INTERFACE:\${_IMPORT_PREFIX}/lib/${LIB_V8}>
    $<INSTALL_INTERFACE:\${_IMPORT_PREFIX}/lib/${LIB_V8_LIBPLATFORM}>
    $<INSTALL_INTERFACE:\${_IMPORT_PREFIX}/lib/${LIB_V8_LIBBASE}>
    $<INSTALL_INTERFACE:\${_IMPORT_PREFIX}/lib/${LIB_ICU_COMMON}>
    $<INSTALL_INTERFACE:\${_IMPORT_PREFIX}/lib/${LIB_ICU_I18N}>
)
target_include_directories(v8 INTERFACE
    $<BUILD_INTERFACE:${_EXTERNAL_PATH}/v8/out.gn/x64.release/include>
    $<INSTALL_INTERFACE:include/v8>
)
add_dependencies(v8 depot_tools)

# Create the CMake version file.
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/v8ConfigVersion.cmake"
    VERSION ${V8_VERSION}
    COMPATIBILITY AnyNewerVersion
)

set(targets_export_name "v8Targets")

install(TARGETS v8
    EXPORT ${targets_export_name}
    LIBRARY DESTINATION lib COMPONENT Runtime
    ARCHIVE DESTINATION lib COMPONENT Development
    RUNTIME DESTINATION bin COMPONENT Runtime
    PUBLIC_HEADER DESTINATION include COMPONENT Development
    BUNDLE DESTINATION bin COMPONENT Runtime
)

# Create the Config file.
include(CMakePackageConfigHelpers)
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/v8Config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/v8Config.cmake"
    INSTALL_DESTINATION ${ConfigPackageLocation}
)

# Install the generated CMake files.
install(EXPORT ${targets_export_name} NAMESPACE "v8::" DESTINATION ${ConfigPackageLocation})
install(
    FILES
        "${CMAKE_CURRENT_BINARY_DIR}/v8ConfigVersion.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/v8Config.cmake"
    DESTINATION
        ${ConfigPackageLocation}
)
install(DIRECTORY ${_EXTERNAL_PATH}/v8/include/ DESTINATION include/v8)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/v8pp/     DESTINATION include/v8pp)
install(
    FILES
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8_LIBBASE}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_V8_LIBPLATFORM}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_ICU_COMMON}
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${LIB_ICU_I18N}
    DESTINATION
        lib
)
install(
    FILES
        ${_EXTERNAL_PATH}/v8/out.gn/x64.release/${ICU_DATA}
    DESTINATION
        lib
)
install(
    FILES
        ${_EXTERNAL_PATH}/v8/LICENSE
        ${_EXTERNAL_PATH}/v8/LICENSE.fdlibm
        ${_EXTERNAL_PATH}/v8/LICENSE.strongtalk
        ${_EXTERNAL_PATH}/v8/LICENSE.v8
        ${_EXTERNAL_PATH}/v8/LICENSE.valgrind
    DESTINATION
        licenses/v8
)
install(
    FILES
        ${CMAKE_SOURCE_DIR}/LICENSE_1_0.txt
    DESTINATION
        licenses/v8pp
)


