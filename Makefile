################################################################################
# Configuration variables are
# - BIN_PATH
# - NOSAN=1 - To disable address sanitizer in debug builds
# - GPROF=1 - To enable gprofile flags in debug builds
# Build mode
# - sample_bin - To build sample bins
################################################################################
SRC_DIR=src
BIN_DIR=bin
OBJ_DIR=obj

ifneq ($(BIN_PATH),)
	BIN_DIR=$(BIN_PATH)
endif

COMMON_DIR=common
SAMPLE_DIR=sample
PERF_DIR=perf

WOLFSSL = wolfssl
BORINGSSL = boringssl

# Binary suffixes
DBG=_dbg
REL=_rel

# Sample binaries
WOLFSSL_T13_SERV_SAMPLE = wolfssl_tls13_server
WOLFSSL_T13_CLNT_SAMPLE = wolfssl_tls13_client

SAMPLE_BIN_DIR=$(BIN_DIR)/$(SAMPLE_DIR)

SAMPLE_BIN=$(SAMPLE_BIN_DIR)/$(WOLFSSL_T13_SERV_SAMPLE) \
	$(SAMPLE_BIN_DIR)/$(WOLFSSL_T13_CLNT_SAMPLE)

COMMON_SRC=$(SRC_DIR)/$(COMMON_DIR)
SAMPLE_SRC=$(SRC_DIR)/$(SAMPLE_DIR)

# Common Code Srcs
COMM_SRC_FILES=$(wildcard $(COMMON_SRC)/*.c)

# Sample Code Srcs
WOLFSSL_T13_SERV_SAMPLE_SRC=$(SAMPLE_SRC)/$(WOLFSSL_T13_SERV_SAMPLE).c $(COMM_SRC_FILES)
WOLFSSL_T13_CLNT_SAMPLE_SRC=$(SAMPLE_SRC)/$(WOLFSSL_T13_CLNT_SAMPLE).c $(COMM_SRC_FILES)

# Common Code Objs
COMM_OBJ=$(addprefix $(OBJ_DIR)/,$(COMM_SRC_FILES:.c=.o))

# Sample Code Objs
WOLFSSL_T13_SERV_SAMPLE_OBJ=$(addprefix $(OBJ_DIR)/,$(WOLFSSL_T13_SERV_SAMPLE_SRC:.c=.o))
WOLFSSL_T13_CLNT_SAMPLE_OBJ=$(addprefix $(OBJ_DIR)/,$(WOLFSSL_T13_CLNT_SAMPLE_SRC:.c=.o))

DEPENDENCY_DIR=dependency

WOLFSSL_MASTER=wolfssl-master
WOLFSSL_DIR=$(DEPENDENCY_DIR)/$(WOLFSSL_MASTER)
WOLFSSL_LIBS=$(WOLFSSL_DIR)/src/.libs/libwolfssl.so
WOLFSSL_LIBS_COPY=$(BIN_DIR)/libwolfssl.so

# Gprofile flags
GPROF_FLAGS =
ifeq ($(GPROF),1)
	GPROF_FLAGS = -p
	NOSAN=1
endif

# Address Sanitizer flags
SANFLAGS = -fsanitize=address
ifeq ($(NOSTATICASAN),)
	ifeq ($(CLANG),)
		SANFLAGS += -static-libasan
	endif
endif
OSSL_SANFLAGS = enable-asan
ifeq ($(NOSAN),1)
	SANFLAGS =
	OSSL_SANFLAGS =
endif

CFLAGS_DBG = -g $(GPROF_FLAGS) -ggdb -O0 -Wall -Werror -fstack-protector-all $(SANFLAGS) -I $(COMMON_SRC)
CFLAGS_REL = -O3 -Wall -Werror -I $(COMMON_SRC)
COMMON_CFLAGS = $(CFLAGS_DBG)
WOLFSSL_CFLAGS = $(CFLAGS_DBG) -I $(WOLFSSL_DIR)

LDFLAGS_DBG = $(GPROF_FLAGS)
WOLFSSL_LDFLAGS = -L $(BIN_DIR) -lwolfssl $(SANFLAGS)

TEST_LDFLAGS = -L $(BIN_DIR) -ltest_common
TEST_OSSL_111_LDFLAGS = $(TEST_LDFLAGS)
TEST_OSSL_300_LDFLAGS = $(TEST_LDFLAGS)

ifeq ($(CC),cc)
	CC=gcc
endif
ifeq ($(AR),ar)
	AR=ar
endif

ifeq ($(CLANG),1)
	CC=clang
	AR=llvm-ar
endif

CP = cp
RM = rm

TARGET=$(SAMPLE_BIN)

#.PHONY all init_task clean clobber test_bin sample_bin perf_bin

all : init_task $(TARGET)

sample_bin : init_task $(SAMPLE_BIN)

WOLFSSL_CONF_ARGS=--enable-tls13 --enable-harden --enable-debug

$(WOLFSSL_LIBS):
	@echo "Building $(WOLFSSL_DIR)..."
	@if [ ! -f $(WOLFSSL_DIR)/.gitignore ]; then \
		cd $(DEPENDENCY_DIR) && tar -zxvf $(WOLFSSL_MASTER).tar.gz > /dev/null; fi
	@cd $(WOLFSSL_DIR) && autoreconf -i > /dev/null
	@cd $(WOLFSSL_DIR) && ./configure $(WOLFSSL_CONF_ARGS) > /dev/null
	@cd $(WOLFSSL_DIR) && $(MAKE) > /dev/null
	@mkdir -p $(BIN_DIR)

$(WOLFSSL_LIBS_COPY):$(WOLFSSL_LIBS)
	@cp $(WOLFSSL_LIBS)* $(BIN_DIR)
	@echo ""

init_task:
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(BIN_DIR)/$(SAMPLE_DIR)
	@mkdir -p $(OBJ_DIR)
	@mkdir -p $(OBJ_DIR)/$(COMMON_SRC)
	@mkdir -p $(OBJ_DIR)/$(SAMPLE_SRC)

$(OBJ_DIR)/$(COMMON_SRC)%.o:$(COMMON_SRC)%.c
	$(CC) $(COMMON_CFLAGS) -c $< -o $@

$(OBJ_DIR)/$(SAMPLE_SRC)/$(WOLFSSL)%.o:$(SAMPLE_SRC)/$(WOLFSSL)%.c \
							           $(WOLFSSL_LIBS_COPY)
	$(CC) $(WOLFSSL_CFLAGS) -c $< -o $@

$(SAMPLE_BIN_DIR)/$(WOLFSSL_T13_SERV_SAMPLE):$(WOLFSSL_T13_SERV_SAMPLE_OBJ)
	$(CC) $^ $(WOLFSSL_LDFLAGS) -o $@
	@echo ""

$(SAMPLE_BIN_DIR)/$(WOLFSSL_T13_CLNT_SAMPLE):$(WOLFSSL_T13_CLNT_SAMPLE_OBJ)
	$(CC) $^ $(WOLFSSL_LDFLAGS) -o $@
	@echo ""

clean:
	@$(RM) -rf *.o *.a
	@$(RM) -rf $(TARGET)
	@$(RM) -rf $(OBJ_DIR) $(BIN_DIR)

clobber: clean
	@echo "Cleaning $(WOLFSSL_DIR)..."
	@if [ -f $(WOLFSSL_DIR)/Makefile ]; then \
		cd $(WOLFSSL_DIR) && $(MAKE) clean > /dev/null; fi
