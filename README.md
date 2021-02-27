# gcc-tools
## Setup
### Target Variables
- `TARGET`
- `BUILD_DIR`
- `LINKER_CFG`
- `SVD`
- `INC_DIRS`
- `SYS_INC_DIRS`
- `SRC_FILES`
- `SRC_DIRS`
- `ASFLAGS`
- `CPPFLAGS`
- `CFLAGS`
- `CXXFLAGS`
- `LDFLAGS`
- `LIBS`

### Library Variables
For each library name in `LIBS`:
- `$(name)_LIB_ROOT`
- `$(name)_ASFLAGS`
- `$(name)_CPPFLAGS`
- `$(name)_CFLAGS`
- `$(name)_CXXFLAGS`
- `$(name)_INC_DIRS`
- `$(name)_SYS_INC_DIRS`
- `$(name)_LIB_FILES`
- `$(name)_LIB_DIRS`

## Use
### Compile
```shell
make -f <target>.mk
```

### Clean
```shell
make -f <target>.mk clean
```
