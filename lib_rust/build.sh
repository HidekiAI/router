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
