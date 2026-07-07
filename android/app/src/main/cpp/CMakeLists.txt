cmake_minimum_required(VERSION 3.22.1)
project(naza_bark_ffi LANGUAGES CXX)

add_library(naza_bark_ffi SHARED
  ../../../../../native/naza_bark_ffi.cpp
)

target_compile_features(naza_bark_ffi PRIVATE cxx_std_17)
target_compile_options(naza_bark_ffi PRIVATE -O3 -fvisibility=hidden)
