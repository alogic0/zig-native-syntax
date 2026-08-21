# Make lexical corpus
include config.mk
CC := cc
FLAGS ?= -O2
MESSAGE = "hello\n<&>"

.PHONY: all
all: build
	$(CC) $(FLAGS) -o app main.c
	@echo "$(MESSAGE)"
