CC       := aarch64-linux-gnu-gcc

.PHONY: default
default: build

.PHONY: build
build: *.s
	$(CC) -g -static -o lab4 $^ -lm
