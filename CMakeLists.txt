# CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
project(boost_test)

find_package(Boost REQUIRED)
add_executable(boost-checker src/main.cpp)
target_link_libraries(boost-checker Boost::boost)

install(TARGETS boost-checker 
        DESTINATION bin)
