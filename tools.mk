CC      := $(TOOLCHAIN_PREFIX)gcc
CXX     := $(TOOLCHAIN_PREFIX)g++
AS      := $(TOOLCHAIN_PREFIX)as
LD      := $(TOOLCHAIN_PREFIX)gcc
AR      := $(TOOLCHAIN_PREFIX)gcc-ar
GDB     := $(TOOLCHAIN_PREFIX)gdb
OBJCOPY := $(TOOLCHAIN_PREFIX)objcopy
SIZE    := $(TOOLCHAIN_PREFIX)size

SRCS := $(SRC_FILES)

ifneq ($(SRC_DIRS),)
SRCS += $(shell find $(SRC_DIRS) -maxdepth 1 -name *.cpp -or -name *.c -or -name *.s -or -name *.S)
endif

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

COMMA :=,
LDFLAGS := \
  $(addprefix -Wl$(COMMA),$(LDFLAGS)) \

LIBS_DEPS := \
  $(foreach _lib,$(LIBS),$(BUILD_DIR)/$(_lib).lib) \

LDLIBS := \
  $(LIBS_DEPS) \
  $(LDLIBS) \

# $1 filename
# $2 ASFLAGS
# $3 CPPFLAGS
# $4 CFLAGS
# $5 CXXFLAGS
# $6 build deps
define generate_build_rule

ifeq ($(suffix $(1)),.s)
$$(BUILD_DIR)/$(1).o: $(1) $(6) $(lastword $(MAKEFILE_LIST))
	@echo Assembling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(AS) $(2) $$< -o $$@
endif

ifeq ($(suffix $(1)),.S)
$$(BUILD_DIR)/$(1).o: $(1) $(6) $(lastword $(MAKEFILE_LIST))
	@echo Assembling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(CC) -c $(2) $$< $(3) -o $$@
endif

ifeq ($(suffix $(1)),.c)
$$(BUILD_DIR)/$(1).o: $(1) $(6) $(lastword $(MAKEFILE_LIST))
	@echo Compiling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(CC) -MM -MP -MF "$$(@:%.o=%.d)" -MT "$$@" $(3) $(4) -E $$<
	@$$(CC) -x c $(3) $(4) -c $$< -o $$@
endif

ifeq ($(suffix $(1)),.cpp)
$$(BUILD_DIR)/$(1).o: $(1) $(6) $(lastword $(MAKEFILE_LIST))
	@echo Compiling $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(CXX) -MM -MP -MF "$$(@:%.o=%.d)" -MT "$$@" $(3) $(5) -E $$<
	@$$(CXX) -x c++ $(3) $(5) -c $$< -o $$@
endif

endef

# $1 lib name
define generate_lib

$(1)_INC_DIRS += $$($(1)_SRC_DIRS)
$(1)_INC_FLAGS := $$(addprefix -iquote,$$($(1)_INC_DIRS))

$(1)_SYS_INC_FLAGS := $$(addprefix -I,$$($(1)_SYS_INC_DIRS))

$(1)_CPPFLAGS := \
  $$($(1)_INC_FLAGS) \
  $$($(1)_SYS_INC_FLAGS) \
  $$($(1)_CPPFLAGS) \
  $$(addprefix -D,$$($(1)_DEFINES)) \

$(1)_LIB_SRCS := $$($(1)_SRC_FILES)

ifneq ($$($(1)_SRC_DIRS),)
$(1)_LIB_SRCS += $$(shell find $$($(1)_SRC_DIRS) -maxdepth 1 -name *.cpp -or -name *.c -or -name *.s -or -name *.S)
endif

$(1)_LIB_OBJS := $$($(1)_LIB_SRCS:%=$$(BUILD_DIR)/%.o)
$(1)_LIB_DEPS := $$($(1)_LIB_SRCS:%=$$(BUILD_DIR)/%.d)

DEPS := $(DEPS) $(1)_LIB_DEPS

$$(BUILD_DIR)/$(1).lib: $$($1_LIB_OBJS)
	@echo Building $$(notdir $$@)...
	@mkdir -p $$(dir $$@)
	@$$(AR) rcs $$@ $$^

$$(shell mkdir -p $$(BUILD_DIR)/$(1))
$$(shell echo ASFLAGS $$($(1)_ASFLAGS) CPPFLAGS $$($(1)_CPPFLAGS) CFLAGS $$($(1)_CFLAGS) CXXFLAGS $$($(1)_CXXFLAGS) > $$(BUILD_DIR)/lib_$(1).build_deps.next)
$$(shell diff $$(BUILD_DIR)/lib_$(1).build_deps.next $$(BUILD_DIR)/lib_$(1).build_deps > /dev/null 2>&1)
ifneq ($$(.SHELLSTATUS),0)
$$(shell mv $$(BUILD_DIR)/lib_$(1).build_deps.next $$(BUILD_DIR)/lib_$(1).build_deps)
endif

$$(foreach _src,$$($(1)_LIB_SRCS),$$(eval $$(call generate_build_rule,$$(_src),$$($(1)_ASFLAGS),$$($(1)_CPPFLAGS),$$($(1)_CFLAGS),$$($(1)_CXXFLAGS),$$(BUILD_DIR)/lib_$(1).build_deps)))

endef

.PHONY: all
all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex
	@$(SIZE) $<

$(foreach _lib,$(LIBS),$(eval $(call generate_lib,$(_lib))))

ifneq ($(LINKER_CFG),)
LINKER_CFG_ARG := -T $(LINKER_CFG)
endif

$(BUILD_DIR)/$(TARGET).elf: $(OBJS) $(LIBS_DEPS) $(LINKER_CFG)
	@echo Linking $(notdir $@)...
	@mkdir -p $(dir $@)
	@$(LD) $(LINKER_CFG_ARG) $(CPPFLAGS) $(LDFLAGS) $(OBJS) -Wl,--start-group $(LDLIBS) -Wl,--end-group -o $@

$(BUILD_DIR)/$(TARGET).hex: $(BUILD_DIR)/$(TARGET).elf
	@echo Creating $(notdir $@)...
	@mkdir -p $(dir $@)
	@$(OBJCOPY) -O ihex $< $@

$(shell mkdir -p $(BUILD_DIR))
$(shell echo ASFLAGS $(ASFLAGS) CPPFLAGS $(CPPFLAGS) CFLAGS $(CFLAGS) CXXFLAGS $(CXXFLAGS) > $(BUILD_DIR)/build_deps.next)
$(shell diff $(BUILD_DIR)/build_deps.next $(BUILD_DIR)/build_deps > /dev/null 2>&1)
ifneq ($(.SHELLSTATUS),0)
$(shell mv $(BUILD_DIR)/build_deps.next $(BUILD_DIR)/build_deps)
endif

$(foreach _src,$(SRCS),$(eval $(call generate_build_rule,$(_src),$(ASFLAGS),$(CPPFLAGS),$(CFLAGS),$(CXXFLAGS),$(BUILD_DIR)/build_deps)))

.PHONY: clean
clean:
	@echo Cleaning...
	@rm -rf $(BUILD_DIR)

-include $(DEPS)
