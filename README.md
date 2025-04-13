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
└── patch/
    ├── wrf_registry.sh
└── tests/
    └── data/
        └── era5_*.grib
    ├── namelist.input
    ├── namelist.wps
    └── test_executables.sh
```

## Features

- **Modular Build Scripts:**    
    Each script (check_gcc.sh, build_libraries.sh, build_wrf_wps.sh, build_geog.sh) is designed to run independently, giving you flexibility to run only the parts you need.
- **Unified Pipeline:**    
    The compile.sh script runs all build scripts sequentially and ensuring the entire process is automated (recommended).
- **Comprehensive Environment Checks:**    
    The suite automatically verifies your build environment, ensuring the correct version of GCC/G++ is used, and that all necessary libraries are present. Furthermore, a compartmentalised environment block is generated outside of the ~/.zshrc file to keep the compilation contained.
- **Automated Dependency Compilation:**    
    Builds and installs required most up-to-date libraries (such as NetCDF, MPI, etc.) with robust logging and error checking.
- **Automated WRF/WPS Build:**    
    Configures and compiles the WRF model and its WPS component with minimal manual intervention.
- **Geography Data Integration:**    
    Downloads, extracts, and integrates WRF geographic data, and updates configuration files (like namelist.wps) automatically.
- **Centralized Logging:**    
    All scripts append to a shared compile.log file, so you have a complete record of the build process.
- **Registry Patching:**    
    Additional variables can be added to/removed from the Registry file prior to compilation to allow for additional WRF output flexibility.
- **Small WRF test:**    
    Six hours of ERA5 data (and relevant namelists) are provided for a quick post-compilation test. A full WRF run, checking all relevant executables, can be executed using test_executables.sh.

## Usage

For the complete pipeline, clone the repository to your directory of choice for WRF compilation and run:
```bash
./compile.sh
```
Which will execute the entire pipeline and log all output to compile.log.

Individual scripts can be run for the following:

| Script Name           | Description                                  | Path                             |
|-----------------------|----------------------------------------------|----------------------------------|
| **check_gcc.sh**      | Verifies that the correct GCC/G++ is installed   | `/build_scripts/check_gcc.sh`   |
| **build_libraries.sh**| Compiles and installs all required libraries   | `/build_scripts/build_libraries.sh` |
| **build_wrf_wps.sh**  | Configures and builds WRF and WPS              | `/build_scripts/build_wrf_wps.sh`|
| **build_geog.sh**     | Downloads and sets up geography data for WRF and adds path to namelist.WPS   | `/build_scripts/build_geog.sh`  |
| **wrf_registry.sh**   | Adds/removes variables to registry.EM_COMMON | `/patch/wrf_registry.sh` |
| **test_executables.sh** | Runs a short WRF simulation to test executables | `/tests/test_executables.sh` |

After compilation, an alias is added to the .zshrc file to allow for the correct MPIRUN to be located when running WRF:

```bash
alias wrfenv='source "/path/to/environment/file/wrf_environment.sh"'
```

To run WRF after compilation, either refresh the terminal instance by opening a new session, or source the .zshrc file. From here, simply activate the environment using 

```bash
wrfenv
```

then which mpirun will return 

```bash
/path/tp/mpich/dir/mpirun
```

allowing WRF to be run using mpirun.

## Tests

The current repository has been tested on the following machines (build time does not include build_geog.sh as internet speeds vary. Keep in mind the WPS geography files are typically ~29G). The execution of compile_wrf.sh can take a long time owing to building all libraries from scratch:

| Hardware                    | Outcome | Build Time |
|-----------------------------|---------|------------|
| M2 Max Macbook Pro (12 CPU) |    ✅   |  00:56:46  |
| M1 Mac Mini (8 CPU)         |    ✅   |  01:17:17  |
| M1 Macbook Air (8 CPU)      |    ✅   |  01:12:14  | 

With the following library versions:

| Library | Version |
|---------|---------|
| MPICH | 4.3.0 |
| HDF5 | 1.14.6 |
| NetCDF-C | 4.9.3 |
| NetCDF-Fortran | 4.6.2 |
| PnetCDF | 1.14.0 |
| Zlib | 1.3.1|
| LibPNG | 1.6.47 |
| Jasper | 1.900.1|

Keep in mind that although Jasper has much more recent releases (v4.x), API changes occurred after v2.0.33 that lead to compilation errors and unexpected behavior when attempting to build WRF. For that reason, the Jasper compilation is hard-coded to version 1.900.1.

## Tests

Post compilation, tests/test_executables.sh should be executed to determine whether all executables have been built correctly and are executable. A small, six hour WRF run for 01 JAN 2020 00-06h is computed with a horizontal resolution of ~20 km. The WRF run test saves all NetCDF files to output, a directory automatically generated inside tests when the script is executed. Timing for each tests with parallel NetCDF writing are as follows:

| Hardware                    | Run Time |
|-----------------------------|----------|
| M2 Max Macbook Pro (12 CPU) | 00:01:06 |
| M1 Mac Mini (8 CPU)         | 00:02:25 |
| M1 Macbook Air (8 CPU)      | 00:02:16 |

build_libraries.sh builds PnetCDF and HDF5 in parallel, allowing for considerable speed-ups when writing WRF output. The scripts can be edited to not compile the PnetCDF library and drop parallel-writing functionality, but it is highly recommended for efficiency purposes. test_executables.sh was performed with parallel writing capabilities and without to determine efficiency increases and to ensure WRF was condfigured with PnetCDF as expected:

For M2 Max Macbook Pro (12 CPU):
| NetCDF Writing | Writing Speed |
|------------------|---------------|
| io_form=2 (not parallel) | 0.33s |
| io_form=11 (parallel) | 0.05s |

- Writing decrease factor: 6.6x

For M1 Mac Mini (8 CPU):
| NetCDF Writing | Writing Speed |
|------------------|---------------|
| io_form=2 (not parallel) | 0.853s |
| io_form=11 (parallel) | 0.149s |

- Writing decrease factor: 5.7x
  
For M1 Macbook Air (8 CPU):
| NetCDF Writing | Writing Speed |
|------------------|---------------|
| io_form=2 (not parallel) | 0.58s |
| io_form=11 (parallel) | 0.08s |

- Writing decrease factor: 7.3x


**Disclaimer**

File writing times are taken as an average of the seven produced during the test. Indeed, file writing times are highly variable and dependent on domain number, domain sizes, resolutions (both vertical and horizontal), etc. Timings given here are representative of the machines tested on and may vary even if the same hardware is used (e.g., there were considerable differences between the M1 Mac Mini and M1 Macbook air, even though they have the same number of CPUs etc.).
