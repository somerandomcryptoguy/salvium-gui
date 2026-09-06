ANDROID_STANDALONE_TOOLCHAIN_PATH ?= /usr/local/toolchain
MANUAL_SUBMODULES ?= OFF
RELEASE_CC ?= gcc-16
RELEASE_CXX ?= g++-16
LINUX_STATIC_IMAGE ?= salvium:build-env-linux-gcc16
STATIC_DEPS_THREADS ?= $(shell nproc 2>/dev/null || echo 2)
QT_STATIC_TEMPLATE_PLUGIN ?= /usr/qml/QtQuick/Templates.2/libqtquicktemplates2plugin.a

host_system := $(shell uname -s)
windows_host := $(filter MINGW% MSYS% CYGWIN%,$(host_system))
linux_host := $(filter Linux,$(host_system))
ifneq ($(windows_host),)
  ifeq ($(origin RELEASE_CC),file)
    RELEASE_CC := gcc
  endif
  ifeq ($(origin RELEASE_CXX),file)
    RELEASE_CXX := g++
  endif
endif
native_target ?= $(if $(MINGW_CHOST),$(MINGW_CHOST),$(shell $(RELEASE_CC) -dumpmachine 2>/dev/null))
native_prefix := $(shell cd $$(dirname $$(command -v $(RELEASE_CC)))/.. 2>/dev/null && pwd)
release_static_generator :=
release_static_platform_args = -D ARCH=$(or ${ARCH},default)
release_builddir = $(builddir)
release_topdir = $(topdir)
release_generator :=
release_platform_args :=
release_compiler_check :=
ifneq ($(linux_host),)
  release_platform_args := -D ARCH="$(or ${ARCH},default)" -D CMAKE_C_COMPILER="$(RELEASE_CC)" -D CMAKE_CXX_COMPILER="$(RELEASE_CXX)"
  release_static_platform_args += -D CMAKE_C_COMPILER="$(RELEASE_CC)" -D CMAKE_CXX_COMPILER="$(RELEASE_CXX)"
  release_compiler_check := check-release-compiler
endif

git_worktree := $(shell git rev-parse --is-inside-work-tree 2>/dev/null)
ifeq ($(git_worktree),true)
  git = yes
endif

builddir := build
topdir := ../..
BOOST_SYSTEM_LIBRARY ?= $(firstword $(wildcard /usr/lib/x86_64-linux-gnu/libboost_system.so /usr/lib/x86_64-linux-gnu/libboost_system.so.*))
ifneq ($(BOOST_SYSTEM_LIBRARY),)
  BOOST_SYSTEM_CMAKE_FLAGS := -DBoost_SYSTEM_LIBRARY_RELEASE=$(BOOST_SYSTEM_LIBRARY) -DBoost_SYSTEM_LIBRARY_DEBUG=$(BOOST_SYSTEM_LIBRARY)
endif
ifeq ($(USE_SINGLE_BUILDDIR), OFF)
  os := $(shell echo  `uname | sed -e 's|[:/\\ \(\)]|_|g'`)
  builddir := $(builddir)/$(os)
  topdir := $(topdir)/..

  deldirs := $(builddir)
else
  deldirs := $(builddir)/debug $(builddir)/release
endif

release_static_builddir := $(builddir)
release_static_topdir := $(topdir)
release_static_environment :=
ifneq ($(windows_host),)
  release_builddir := build/$(native_target)
  release_topdir := ../../..
  release_generator := -G "MSYS Makefiles"
  release_platform_args := -D ARCH="x86-64" -D BUILD_TAG="win-x64"
  release_static_builddir := build/$(native_target)
  release_static_topdir := ../../..
  release_static_environment := CMAKE_PREFIX_PATH="$(native_prefix)/qt5-static" PKG_CONFIG_PATH="$(native_prefix)/qt5-static/lib/pkgconfig"
  release_static_generator := -G "MSYS Makefiles"
  release_static_platform_args := -D ARCH="x86-64" -D BUILD_TAG="win-x64" -D CMAKE_C_COMPILER="$(RELEASE_CC)" -D CMAKE_CXX_COMPILER="$(RELEASE_CXX)"
endif

.PHONY: submodules check-release-compiler release release-static release-static-native

# Keep the embedded core and all of its dependencies at the revisions pinned
# by this GUI commit.  Do not use --force here: a developer's real source
# edits must stop the build rather than being overwritten.
submodules:
	git submodule sync --recursive
	git submodule update --init --recursive

check-release-compiler:
	@if ! "$(RELEASE_CC)" -dumpfullversion | grep -Eq '^16([.]|$$)'; then echo "error: Linux releases require GCC 16 (RELEASE_CC=$(RELEASE_CC))." >&2; exit 1; fi
	@if ! "$(RELEASE_CXX)" -dumpfullversion | grep -Eq '^16([.]|$$)'; then echo "error: Linux releases require G++ 16 (RELEASE_CXX=$(RELEASE_CXX))." >&2; exit 1; fi

default:
	mkdir -p build && cd build && cmake -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release $(BOOST_SYSTEM_CMAKE_FLAGS) .. && $(MAKE)
debug:
	mkdir -p build && cd build && cmake -D DEV_MODE=$(or ${DEV_MODE},ON) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D CMAKE_BUILD_TYPE=Debug $(BOOST_SYSTEM_CMAKE_FLAGS) .. && $(MAKE) VERBOSE=1
debug-static:
	mkdir -p build && cd build && cmake -D STATIC=ON -D DEV_MODE=$(or ${DEV_MODE},ON) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D CMAKE_BUILD_TYPE=Debug .. && $(MAKE) VERBOSE=1

depends:
	mkdir -p build/$(target)/release
	cd build/$(target)/release && cmake -D STATIC=ON -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D BUILD_TAG=$(tag) -D CMAKE_BUILD_TYPE=Release -D CMAKE_TOOLCHAIN_FILE=/depends/$(target)/share/toolchain.cmake ../../.. && $(MAKE)

devmode:
	mkdir -p build && cd build && cmake -D DEV_MODE=$(or ${DEV_MODE},ON) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release .. && $(MAKE)
clean:
	mkdir -p build && cd build && rm -rf *
scanner:
	mkdir -p build && cd build && cmake -D DEV_MODE=$(or ${DEV_MODE},ON) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D WITH_SCANNER=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release .. && $(MAKE)

release: submodules $(release_compiler_check)
	mkdir -p $(release_builddir)/release && cd $(release_builddir)/release && cmake $(release_generator) -D BUILD_TESTS=OFF -D STATIC=OFF -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D CMAKE_BUILD_TYPE=Release $(release_platform_args) $(release_topdir) && $(MAKE)

release-linux-armv8:
	mkdir -p $(builddir)/release && cd $(builddir)/release && cmake -D DEV_MODE=$(or ${DEV_MODE},OFF) -D ARCH="armv8-a" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG="linux-armv8" $(topdir) && $(MAKE)

release-linux-ppc64le:
	mkdir -p $(builddir)/release && cd $(builddir)/release && cmake -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D ARCH="ppc64le" -D CMAKE_BUILD_TYPE=Release $(topdir) && $(MAKE)

release-static-native: submodules $(release_compiler_check)
	mkdir -p $(release_static_builddir)/release && cd $(release_static_builddir)/release && $(release_static_environment) cmake $(release_static_generator) -D BUILD_TESTS=OFF -D STATIC=ON -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release $(release_static_platform_args) $(release_static_topdir) && $(MAKE) net -j1 && $(MAKE)

ifneq ($(linux_host),)
release-static: submodules
	@if [ -f "$(QT_STATIC_TEMPLATE_PLUGIN)" ]; then \
		$(MAKE) release-static-native; \
	elif command -v docker >/dev/null 2>&1; then \
		if ! docker image inspect "$(LINUX_STATIC_IMAGE)" >/dev/null 2>&1; then \
			echo "Static Qt is not installed; building $(LINUX_STATIC_IMAGE) with cached static dependencies."; \
			docker build --tag "$(LINUX_STATIC_IMAGE)" --build-arg THREADS="$(STATIC_DEPS_THREADS)" --file Dockerfile.linux . || exit $$?; \
		fi; \
		echo "Static Qt is not installed on the host; continuing in $(LINUX_STATIC_IMAGE)."; \
		docker run --rm --user "$$(id -u):$$(id -g)" -e HOME=/tmp \
			-v "$(CURDIR):/salvium-gui" -w /salvium-gui "$(LINUX_STATIC_IMAGE)" \
			$(MAKE) release-static-native USE_SINGLE_BUILDDIR=OFF; \
	else \
		echo "error: static Qt is unavailable and Docker is not installed." >&2; \
		exit 1; \
	fi
else
release-static: release-static-native
endif

release-static-mac-x86_64:
	mkdir -p $(builddir)/release &&	cd $(builddir)/release && cmake -D STATIC=ON -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D ARCH="x86-64" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release $(topdir) && $(MAKE)

debug-static-win64:
	mkdir -p $(builddir)/debug && cd $(builddir)/debug && cmake -D STATIC=ON -G "MSYS Makefiles" -D DEV_MODE=$(or ${DEV_MODE},ON) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D ARCH="x86-64" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Debug -D BUILD_TAG="win-x64" -D CMAKE_TOOLCHAIN_FILE=$(topdir)/cmake/64-bit-toolchain.cmake -D MSYS2_FOLDER=$(shell cd ${MINGW_PREFIX}/.. && pwd -W) -D MINGW=ON $(topdir) && $(MAKE)

debug-static-mac64:
	mkdir -p $(builddir)/debug
	cd $(builddir)/debug && cmake -D STATIC=ON -D DEV_MODE=$(or ${DEV_MODE},ON) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D ARCH="x86-64" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Debug -D BUILD_TAG="mac-x64" $(topdir) && $(MAKE)

release-static-win64:
	mkdir -p $(builddir)/release && cd $(builddir)/release && cmake -D STATIC=ON -G "MSYS Makefiles" -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D ARCH="x86-64" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG="win-x64" -D CMAKE_TOOLCHAIN_FILE=$(topdir)/cmake/64-bit-toolchain.cmake -D MSYS2_FOLDER=$(shell cd ${MINGW_PREFIX}/.. && pwd -W) -D MINGW=ON $(topdir) && $(MAKE)

release-win64:
	mkdir -p $(builddir)/release && cd $(builddir)/release && cmake -D STATIC=OFF -G "MSYS Makefiles" -D DEV_MODE=$(or ${DEV_MODE},OFF) -DMANUAL_SUBMODULES=${MANUAL_SUBMODULES} -D ARCH="x86-64" -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG="win-x64" -D CMAKE_TOOLCHAIN_FILE=$(topdir)/cmake/64-bit-toolchain.cmake -D MSYS2_FOLDER=$(shell cd ${MINGW_PREFIX}/.. && pwd -W) -D MINGW=ON $(topdir) && $(MAKE)
