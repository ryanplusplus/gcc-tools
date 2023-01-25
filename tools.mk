CC      = $(TOOLCHAIN_PREFIX)gcc
CXX     = $(TOOLCHAIN_PREFIX)g++
AS      = $(TOOLCHAIN_PREFIX)as
LD      = $(TOOLCHAIN_PREFIX)gcc
AR      = $(TOOLCHAIN_PREFIX)gcc-ar
GDB     = $(TOOLCHAIN_PREFIX)gdb
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
SIZE    = $(TOOLCHAIN_PREFIX)size

define capture_version
"$(shell $1 --version | head -n 1)"
endef

CC_VERSION      := $(call capture_version,$(CC))
CXX_VERSION     := $(call capture_version,$(CXX))
AS_VERSION      := $(call capture_version,$(AS))
LD_VERSION      := $(call capture_version,$(LD))
AR_VERSION      := $(call capture_version,$(AR))
GDB_VERSION     := $(call capture_version,$(GDB))
OBJCOPY_VERSION := $(call capture_version,$(OBJCOPY))
SIZE_VERSION    := $(call capture_version,$(SIZE))

SRCS := $(SRC_FILES)

ifneq ($(SRC_DIRS),)
SRCS += $(shell find $(SRC_DIRS) -maxdepth 1 -name *.cpp -or -name *.c -or -name *.s -or -name *.S)
endif

SRCS := $(sort $(SRCS))
OBJS := $(SRCS:%=$(BUILD_DIR)/%.o)
DEPS := $(SRCS:%=$(BUILD_DIR)/%.d)

INC_DIRS += $(SRC_DIRS)
INC_FLAGS := $(addprefix -iquote,$(INC_DIRS))

SYS_INC_FLAGS := $(addprefix -I,$(SYS_INC_DIRS))

CPPFLAGS := \
  $(INC_FLAGS) \
  $(SYS_INC_FLAGS) \
  $(CPPFLAGS) \
  $(addprefix -D,$(DEFINES)) \

LIBS_DEPS := \
  $(foreach _lib,$(LIBS),$(BUILD_DIR)/$(_lib).lib) \

LDLIBS := \
  $(LIBS_DEPS) \
  $(LDLIBS) \

# $1 filename
# $2 flags to capture
define capture_flags
$(shell mkdir -p $(dir $1))
$(shell rm -rf $1.next)
$(foreach flag,$2,$(shell echo $(flag):=$($(flag)) >> $1.next))
$(shell if cmp -s $1.next $1; then rm $1.next; else mv $1.next $1; fi)
endef

# $1 filename
# $2 ASFLAGS
# $3 CPPFLAGS
# $4 CFLAGS
# $5 CXXFLAGS
# $6 build deps
define generate_build_rule
$$(BUILD_DIR)/$1.o: $1 $6 $(lastword $(MAKEFILE_LIST)) $(BUILD_DEPS)
ifeq ($(suffix $1),.s)
	@echo Assembling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(AS) $2 $$< -o $$@
else ifeq ($(suffix $1),.S)
	@echo Assembling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(CC) -c $2 $$< $3 -o $$@
else ifeq ($(suffix $1),.c)
	@echo Compiling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(CC) -x c -MMD -MP -MF "$$(@:%.o=%.d)" -MT "$$@" $3 $4 -c $$< -o $$@
else ifeq ($(suffix $1),.cpp)
	@echo Compiling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(CXX) -x c++ -MMD -MP -MF "$$(@:%.o=%.d)" -MT "$$@" $3 $5 -c $$< -o $$@
endif

endef

# $1 lib name
# $2 lib type (LIB or INTERFACE_LIB)
define generate_lib

$1_INC_DIRS += $$($1_SRC_DIRS)
$1_INC_FLAGS := $$(addprefix -iquote,$$($1_INC_DIRS))

$1_SYS_INC_FLAGS := $$(addprefix -I,$$($1_SYS_INC_DIRS))

$1_CPPFLAGS := \
  $$($1_INC_FLAGS) \
  $$($1_SYS_INC_FLAGS) \
  $$($1_CPPFLAGS) \
  $$(addprefix -D,$$($1_DEFINES)) \

$1_LIB_SRCS := $$($1_SRC_FILES)

ifneq ($$($1_SRC_DIRS),)
$1_LIB_SRCS += $$(shell find $$($1_SRC_DIRS) -maxdepth 1 -name *.cpp -or -name *.c -or -name *.s -or -name *.S)
endif

$1_LIB_SRCS := $$(sort $$($1_LIB_SRCS))
$1_LIB_OBJS := $$($1_LIB_SRCS:%=$$(BUILD_DIR)/%.o)
$1_LIB_DEPS := $$($1_LIB_SRCS:%=$$(BUILD_DIR)/%.d)

DEPS := $(DEPS) $$($1_LIB_DEPS)

ifeq ($2,LIB)
unused := $$(call capture_flags,$$(BUILD_DIR)/lib_$1.ar.flags,AR_VERSION)

$$(BUILD_DIR)/$1.lib: $$($1_LIB_OBJS) $$(BUILD_DIR)/lib_$1.ar.flags
	@echo Building $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(AR) rcs $$@ $$^
endif

ifeq ($2,INTERFACE_LIB)
OBJS += $$($1_LIB_OBJS)
endif

unused := $$(call capture_flags,$$(BUILD_DIR)/lib_$1.build.flags,AS_VERSION CC_VERSION CXX_VERSION AR_VERSION $1_ASFLAGS $1_CPPFLAGS $1_CFLAGS $1_CXXFLAGS)

$$(foreach _src,$$($1_LIB_SRCS),$$(eval $$(call generate_build_rule,$$(_src),$$($1_ASFLAGS),$$($1_CPPFLAGS),$$($1_CFLAGS),$$($1_CXXFLAGS),$$(BUILD_DIR)/lib_$1.build.flags)))

endef

$(foreach _lib,$(LIBS),$(eval $(call generate_lib,$(_lib),LIB)))
$(foreach _lib,$(INTERFACE_LIBS),$(eval $(call generate_lib,$(_lib),INTERFACE_LIB)))

ifneq ($(LINKER_SCRIPT),)
LINKER_SCRIPT_ARG := -T $(LINKER_SCRIPT)
endif

unused := $(call capture_flags,$(BUILD_DIR)/link.flags,LD_VERSION LINKER_SCRIPT_ARG CPPFLAGS LDFLAGS OBJS LDLIBS)

$(BUILD_DIR)/$(TARGET).elf: $(OBJS) $(LIBS_DEPS) $(LINKER_SCRIPT) $(BUILD_DIR)/link.flags
	@echo Linking $(notdir $@)...
	@mkdir -p $(dir $@)
	@$(LD) $(LINKER_SCRIPT_ARG) $(CPPFLAGS) $(LDFLAGS) $(OBJS) -Wl,--start-group $(LDLIBS) -Wl,--end-group -o $@

unused := $(call capture_flags,$(BUILD_DIR)/hex.flags,OBJCOPY_VERSION)

$(BUILD_DIR)/$(TARGET).hex: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/hex.flags
	@echo Creating $(notdir $@)...
	@mkdir -p $(dir $@)
	@$(OBJCOPY) -O ihex $< $@

unused := $(call capture_flags,$(BUILD_DIR)/build.flags,AS_VERSION CC_VERSION CXX_VERSION ASFLAGS CPPFLAGS CFLAGS CXXFLAGS)

$(foreach _src,$(SRCS),$(eval $(call generate_build_rule,$(_src),$(ASFLAGS),$(CPPFLAGS),$(CFLAGS),$(CXXFLAGS),$(BUILD_DIR)/build.flags)))

.PHONY: clean
clean:
	@echo Cleaning...
	@rm -rf $(BUILD_DIR)

-include $(DEPS)
