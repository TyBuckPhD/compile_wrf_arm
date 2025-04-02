# Compiling WRF For Mac ARM Architecture

## Table of Contents

- [Introduction](#introduction)
- [Installation](#installation)
- [Structure](#structure)
- [Features](#features)
- [Usage](#usage)
- [Tests](#tests)

## Introduction

The ever-increasing computational capabilities of local machines in recent years has allowed for computationally expensive and complex models to be run efficiently outside of high-performance computational clusters. The introduction of Mac ARM (Silicon) brought on a significant leap in computational availability for the average person, yet the move away from x86 architecture meant that many compilers and libraries were incompatible on release. However, nowadays most (if not all) compilers and libraries are compatible with the ARM architecture, allowing for complex models to be compiled on both architectures – including WRF.

Unfortunately, compiling WRF on ARM architecture is relatively complex compared to x86, with specific compiler paths and niche flags required when configuring several libraries that are not well documented. In this repository, a standardised, modulised set of scripts are provided to allow for the simple configuration and compilation of the necessary compilers, libraries, and the model itself with a single execution.

## Installation 

To git clone the repository:
```bash
git clone https://github.com/TyBuckPhD/compile_wrf_arm
```

## Structure

The repository is structured as follows:
```
compile_wrf_arm/
├── compile.sh
└── build_scripts/
    ├── check_gcc.sh
    ├── build_libraries.sh
    ├── build_wrf_wps.sh
    └── build_geog.sh
```

## Features

- **Modular Build Scripts:**    
    Each script (check_gcc.sh, build_libraries.sh, build_wrf_wps.sh, build_geog.sh) is designed to run independently, giving you flexibility to run only the parts you need.
- **Unified Pipeline:**    
    The compile.sh script runs all build scripts sequentially and ensuring the entire process is automated (recommended).
- **Comprehensive Environment Checks:**    
    The suite automatically verifies your build environment, ensuring the correct version of GCC/G++ is used, and that all necessary libraries are present.
- **Automated Dependency Compilation:**    
    Builds and installs required libraries (such as NetCDF, MPI, etc.) with robust logging and error checking.
- **Automated WRF/WPS Build:**    
    Configures and compiles the WRF model and its WPS component with minimal manual intervention.
- **Geography Data Integration:**    
    Downloads, extracts, and integrates WRF geographic data, and updates configuration files (like namelist.wps) automatically.
- **Centralized Logging:**    
    All scripts append to a shared compile.log file, so you have a complete record of the build process.

## Usage

For the complete pipeline, clone the repository to your directory of choice for WRF compilation and run:
```bash
./compile.sh
```
Which will execute the entire pipeline and log all output to compile.log.

Individual scripts can be run for the following:

| Script Name           | Description                                  | Path                             |
|-----------------------|----------------------------------------------|----------------------------------|
| **check_gcc.sh**      | Verifies that the correct GCC/G++ is installed   | `./build_scripts/check_gcc.sh`   |
| **build_libraries.sh**| Compiles and installs all required libraries   | `./build_scripts/build_libraries.sh` |
| **build_wrf_wps.sh**  | Configures and builds WRF and WPS              | `./build_scripts/build_wrf_wps.sh`|
| **build_geog.sh**     | Downloads and sets up geography data for WRF   | `./build_scripts/build_geog.sh`  |

## Tests

The current repository has been tested on the following machines:

| Hardware                    | Outcome |
|-----------------------------|---------|
| M2 Max Macbook Pro (12 CPU) |    ✅   | 
