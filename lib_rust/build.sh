#!/bin/bash
# Assumes dir matches lib-name!
# arg1: platform
# arg2...: libs
_ARG1_PLATFORM="windows"
# NOTE: Do not add shared and autoload crates here, instead, use Cargo.toml with "path" to point to the crate
# basic rule-of-thumb: if it exports an entry point, it be added to the libs list here:
_ARG2_LIBS="autoload_primitives block_units"
_GODOT_PROJECT="../app_godot/"

# NOTE: Even if using 4.2.1 (i.e. --dump-extension-api says it's 4.2.1), you only set major/minor and set the version to "4.2" instead of "4.2.1"
# or else you will get a 'No GDExtension library found for current OS and architecture' error
_GODOT_VERSION="4.1"

if [ x"$1" != x"" ]; then
  _ARG1_PLATFORM=$1
  shift

  if [ x"$1" != x"" ]; then
    _ARG2_LIBS=$@
  fi
fi


# let's first check the version of the API
 pushd . ; cd /tmp ; $GODOT4_BIN --headless --dump-extension-api ; head  extension_api.json ; popd
 echo "Will be setting VERSION: 'compatibility_minimum = ${_GODOT_VERSION}' in the .gdextension file..."

# Aarg1: libname (i.e. "lib_rust_1")
# Arg2: (Optional) Platform; if not passed, assumes Linux
# Arg3: (Optional) target; if not passed, assumes Debug
# Arg4: (Optional) Arch; if not passed, assumes x86_64
function make_libname() {
    if [ x"$1" == x"" ]; then
        echo "#ERROR: Must pass libname as arg1"
        exit -666
    fi
    _ARG1_LIBNAME=$1
    shift
    _LIBNAME="lib${_ARG1_LIBNAME}"

    # defaults:
    _PLATFORM="linux"
    _ARCH="x86_64"
    _PLATFORM_EXT="so"
    _TARGET="debug"

    if [ x"$1" != x"" ]; then
        _PLATFORM=$1
        shift
        if [ x"$1" != x"" ]; then
            _TARGET=$1
            shift
        fi
    fi

    if [ "${_PLATFORM}" == "windows" ]; then
        _LIBNAME="${_ARG1_LIBNAME}"
        _PLATFORM_EXT="dll"
    elif [ "${_PLATFORM}" == "macos" ]; then
        echo "# NOTE/WARNING: Don't really care to test macos x86_64 and arm...  so fix this yourself :P"
        _PLATFORM_EXT="dylib"
    fi

    # NOTE: Though this format is unnecessary, especially since you can distinctly spot .so vs .dll to know that which file belongs to which OS
    # but having it named explicit like this will help on flattened directory structure where filename is the namespace
    #echo "target/${_TARGET}/${_LIB_NAME}.${_PLATFORM}.template_${_TARGET}.${_ARCH}.${_PLATFORM_EXT}"
    echo "target/${_TARGET}/${_LIB_NAME}.${_PLATFORM_EXT}"
}


# Arg1: libname
# Arg2: DEBUG target
# Arg3: Release target
# Arg4: Platform
function make_gdext() {
    if [ x"$1" == x"" ]; then
        echo "#ERROR: Must pass libname as arg1"
        exit -666
    fi

    _LIB_DIR=$(basename $(pwd))

    echo ""
    echo "[configuration]"
    echo "entry_symbol = \"gdext_rust_init\""
    echo "compatibility_minimum = ${_GODOT_VERSION}"
    echo ""
    echo "[libraries]"

    if [ "$4" == "linux" ]; then
        echo "linux.debug.x86_64 =     \"res://../${_LIB_DIR}/$1/$2\""
        echo "linux.release.x86_64 =   \"res://../${_LIB_DIR}/$1/$3\""
        echo "linux.x86_64 =           \"res://../${_LIB_DIR}/$1/$2\""
    elif [ "$4" == "windows" ]; then
        echo "windows.debug.x86_64 =   \"res://../${_LIB_DIR}/$1/$2\""
        echo "windows.release.x86_64 = \"res://../${_LIB_DIR}/$1/$3\""
        echo "windows.x86_64 =         \"res://../${_LIB_DIR}/$1/$2\""
    elif [ "$4" == "macos" ]; then
        echo "macos.debug =            \"res://../${_LIB_DIR}/$1/$2\""
        echo "macos.release =          \"res://../${_LIB_DIR}/$1/$3\""
        echo "macos =                  \"res://../${_LIB_DIR}/$1/$2\""
    elif [ "$4" == "macos.arm64" ]; then
        echo "macos.debug.arm64 =      \"res://../${_LIB_DIR}/$1/$2\""
        echo "macos.release.arm64 =    \"res://../${_LIB_DIR}/$1/$3\""
        echo "macos.arm64 =            \"res://../${_LIB_DIR}/$1/$2\""
    fi
}

for _LIB_NAME in ${_ARG2_LIBS}; do
  echo -e "\nBuilding ${_LIB_NAME}"
  pushd .

  cd ${_LIB_NAME}
  cargo build
  _SRC="target/debug/lib${_LIB_NAME}.so"
  _T=$(make_libname ${_LIB_NAME})
  if [ ${_ARG1_PLATFORM} = "windows" ]; then
    _SRC="target/debug/${_LIB_NAME}.dll"
      _T=$(make_libname ${_LIB_NAME} "windows" "debug")
  fi
  echo -e "\n ################# GDExtension: ${_SRC}"
  cp -v ${_SRC} ${_T}
  ls -lAh ${_T}
  _TDEBUG=${_T}

  cargo build --release
  _SRC="target/release/lib${_LIB_NAME}.so"
  _T=$(make_libname ${_LIB_NAME} "linux" "release") 
  _SRC="target/release/lib${_LIB_NAME}"
  if [ ${_ARG1_PLATFORM} = "windows" ]; then
    _SRC="target/release/${_LIB_NAME}.dll"
    _T=$(make_libname ${_LIB_NAME} "windows" "release") 
  fi
  echo "################# GDExtension: ${_SRC}"
  cp -v ${_SRC} ${_T}
  ls -lAh ${_T}
  _TRELEASE=${_T}

  popd

  make_gdext ${_LIB_NAME} ${_TDEBUG} ${_TRELEASE} ${_ARG1_PLATFORM} > "${_GODOT_PROJECT}/${_LIB_NAME}.gdextension"
  cat "${_GODOT_PROJECT}/${_LIB_NAME}.gdextension"
done
