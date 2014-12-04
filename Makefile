CC=dmd # Compiler to use

# The files to compile
FILES=source/*.d

# The output folder and the output binary
OUTPUT=bin/
OUTPUT_BIN=$(OUTPUT)assembler

# Where to store the output of the profiling
LOGS_DIR=logs/

# Where to store the documentation files
DOC_DIR=doc/

# Flags used with dmd
CC_DEV_FLAGS=-w -debug # Flags to use when developing
CC_TEST_FLAGS=-unittest # will be ran when testing along with DEV flags
CC_REL_FLAGS=-w -release -O -inline # Flags to use when builing a release
CC_PROF_FLAGS=-profile -cov # will be used along the DEV flags
CC_DOC_FLAGS=-D -Dd$(DOC_DIR) # flags for generating doc files


build:
	mkdir -p $(OUTPUT)
	$(CC) $(CC_DEV_FLAGS) $(FILES) -of$(OUTPUT_BIN)

run:
	./$(OUTPUT_BIN)

release:
	mkdir -p $(OUTPUT)
	$(CC) $(CC_REL_FLAGS) $(FILES) -of$(OUTPUT_BIN)

profile:
	$(CC) $(CC_DEV_FLAGS) $(CC_PROF_FLAGS) $(FILES) -of$(OUTPUT_BIN)
	mkdir -p $(LOGS_DIR)
	./$(OUTPUT_BIN)
	mv *.lst trace.* $(LOGS_DIR)

test:
	mkdir -p $(OUTPUT)
	$(CC) $(CC_DEV_FLAGS) $(CC_TEST_FLAGS) $(FILES) -of$(OUTPUT_BIN)

gendoc:
	$(CC) $(CC_DEV_FLAGS) $(CC_DOC_FLAGS) $(FILES) -of$(OUTPUT_BIN)
