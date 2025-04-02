# Compiling WRF For Mac ARM Architecture

The ever-increasing computational capabilities of local machines in recent years has allowed for computationally expensive and complex models to be run efficiently outside of high-performance computational clusters. The introduction of Mac ARM (Silicon) brought on a significant leap in computational availability for the average person, yet the move away from x86 architecture meant that many compilers and libraries were incompatible on release. However, nowadays most (if not all) compilers and libraries are compatible with the ARM architecture, allowing for complex models to be compiled on both architectures – including WRF.

Unfortunately, compiling WRF on ARM architecture is relatively complex compared to x86, with specific compiler paths and niche flags required when configuring several libraries that are not well documented. In this repository, a standardised, modulised set of scripts are provided to allow for the simple configuration and compilation of the necessary compilers, libraries, and the model itself with a single execution.

## Features
