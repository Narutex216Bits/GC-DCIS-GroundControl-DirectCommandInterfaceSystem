cmake_minimum_required(VERSION 3.10)
project(MesaMapa VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTKMM REQUIRED gtkmm-3.0)
pkg_check_modules(CHAMPLAIN REQUIRED champlain-0.12 champlain-gtk-0.12)

find_path(MOSQUITTO_INCLUDE_DIR NAMES mosquitto.h)
find_path(MOSQUITTOPP_INCLUDE_DIR NAMES mosquittopp.h)
find_library(MOSQUITTO_LIBRARY NAMES mosquitto)
find_library(MOSQUITTOPP_LIBRARY NAMES mosquittopp)

find_path(JSON_INCLUDE_DIR NAMES nlohmann/json.hpp PATHS /usr/include /usr/local/include)

add_executable(mesamapa
    src/main.cpp
    src/MQTTClient.cpp
    src/PlayerManager.cpp
)

target_include_directories(mesamapa PRIVATE
    ${GTKMM_INCLUDE_DIRS}
    ${CHAMPLAIN_INCLUDE_DIRS}
    ${MOSQUITTO_INCLUDE_DIR}
    ${MOSQUITTOPP_INCLUDE_DIR}
    ${JSON_INCLUDE_DIR}
)

target_link_libraries(mesamapa
    ${GTKMM_LIBRARIES}
    ${CHAMPLAIN_LIBRARIES}
    ${MOSQUITTO_LIBRARY}
    ${MOSQUITTOPP_LIBRARY}
    pthread
)

target_compile_options(mesamapa PRIVATE -Wall -Wextra)