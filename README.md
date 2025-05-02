```sh
# Fetch TinyUSB repo
$ git submodule update --init

# Install TinyUSB dependenciess, expects Python to be in PATH
$ zig build get-deps

$ zig build --search-prefix "C:/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.2 rel1/arm-none-eabi" --libc .\arm-libc.txt
```
