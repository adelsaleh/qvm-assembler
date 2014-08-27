# Quantum Assembler

This repository will hold the code and some basic documentation about the
quantum assembly language and the assembler. The documentation will also include
the Instruction Set.

# How to build
## Basic Building
```
make
```
Basic building is what to use if you want to build and run as quickly as
possible. It will compile the project outputting warnings and executing `debug`
blocks. The output binary can be found in `bin/`

## Profiling
```
make profile
```
This command will compile and run your code with flags suitable for profiling
and producing code coverage reports. The flags also include those of basic
building. The reports can be found in the `logs/` directory.

## Testing
```
make test
```
This command will run the same flags as those of the basic building alongside
a flag to compile `unittest` blocks.
## Release Building
```
make release
```
This command will perform optimizations when compiling, suitable for release
code. The resulting binary can be found in `bin/`.

# How to run
```
make run
```
This command is enough to run the program
