#!/bin/bash

# INFO: Modified for shared builds from https://github.com/markus-perl/ffmpeg-build-script
# LICENSE: https://github.com/markus-perl/ffmpeg-build-script/blob/master/LICENSE

PROGNAME=$(basename "$0")
FFMPEG_VERSION=6.0
SCRIPT_VERSION=1.38
CWD=$(pwd)
PACKAGES="$CWD/packages"
WORKSPACE="$CWD/workspace"
CFLAGS="-I$WORKSPACE/include"
LDFLAGS="-L$WORKSPACE/lib"
LDEXEFLAGS=""
EXTRALIBS="-ldl -lpthread -lm -lz"
MACOS_M1=false
CONFIGURE_OPTIONS=()
NONFREE_AND_GPL=false
LATEST=false

. /etc/*-release
arch=`uname -m`
isBuster=false
checkBuster=`cat /etc/*-release | grep buster`
if [ ! -z "$checkBuster" ]; then
 isBuster=true
fi


echo "Building for $OSTYPE"
echo "LDFLAGS are $LDFLAGS"

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
if [[ -n "$NUMJOBS" ]]; then
  MJOBS="$NUMJOBS"
elif [[ -f /proc/cpuinfo ]]; then
  MJOBS=$(grep -c processor /proc/cpuinfo)
else
  MJOBS=4
fi

make_dir() {
  remove_dir "$1"
  if ! mkdir "$1"; then
    printf "\n Failed to create dir %s" "$1"
    exit 1
  fi
}

remove_dir() {
  if [ -d "$1" ]; then
    rm -r "$1"
  fi
}

download() {
  # download url [filename[dirname]]

  DOWNLOAD_PATH="$PACKAGES"
  DOWNLOAD_FILE="${2:-"${1##*/}"}"

  if [[ "$DOWNLOAD_FILE" =~ tar. ]]; then
    TARGETDIR="${DOWNLOAD_FILE%.*}"
    TARGETDIR="${3:-"${TARGETDIR%.*}"}"
  else
    TARGETDIR="${3:-"${DOWNLOAD_FILE%.*}"}"
  fi

  if [ ! -f "$DOWNLOAD_PATH/$DOWNLOAD_FILE" ]; then
    echo "Downloading $1 as $DOWNLOAD_FILE"
    curl -L --silent -o "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$1"

    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      echo ""
      echo "Failed to download $1. Exitcode $EXITCODE. Retrying in 10 seconds"
      sleep 10
      curl -L --silent -o "$DOWNLOAD_PATH/$DOWNLOAD_FILE" "$1"
    fi

    EXITCODE=$?
    if [ $EXITCODE -ne 0 ]; then
      echo ""
      echo "Failed to download $1. Exitcode $EXITCODE"
      exit 1
    fi

    echo "... Done"
  else
    echo "$DOWNLOAD_FILE has already downloaded."
  fi

  make_dir "$DOWNLOAD_PATH/$TARGETDIR"

  if [[ "$DOWNLOAD_FILE" == *"patch"* ]]; then
    return
  fi

  if [ -n "$3" ]; then
    if ! tar -xvf "$DOWNLOAD_PATH/$DOWNLOAD_FILE" -C "$DOWNLOAD_PATH/$TARGETDIR" 2>/dev/null >/dev/null; then
      echo "Failed to extract $DOWNLOAD_FILE"
      exit 1
    fi
  else
    if ! tar -xvf "$DOWNLOAD_PATH/$DOWNLOAD_FILE" -C "$DOWNLOAD_PATH/$TARGETDIR" --strip-components 1 2>/dev/null >/dev/null; then
      echo "Failed to extract $DOWNLOAD_FILE"
      exit 1
    fi
  fi

  echo "Extracted $DOWNLOAD_FILE"

  cd "$DOWNLOAD_PATH/$TARGETDIR" || (
    echo "Error has occurred."
    exit 1
  )
}

execute() {
  echo "$ $*"

  OUTPUT=$("$@" 2>&1)

  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "$OUTPUT"
    echo ""
    echo "Failed to Execute $*" >&2
    exit 1
  fi
}

build() {
  echo ""
  echo "building $1 - version $2"
  echo "======================="

  if [ -f "$PACKAGES/$1.done" ]; then
    if grep -Fx "$2" "$PACKAGES/$1.done" >/dev/null; then
      echo "$1 version $2 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
      return 1
    elif $LATEST; then
      echo "$1 is outdated and will be rebuilt with latest version $2"
      return 0
    else
      echo "$1 is outdated, but will not be rebuilt. Pass in --latest to rebuild it or remove $PACKAGES/$1.done lockfile."
      return 1
    fi
  fi

  return 0
}

command_exists() {
  if ! [[ -x $(command -v "$1") ]]; then
    return 1
  fi

  return 0
}

library_exists() {
  if ! [[ -x $(pkg-config --exists --print-errors "$1" 2>&1 >/dev/null) ]]; then
    return 1
  fi

  return 0
}

build_done() {
  echo "$2" > "$PACKAGES/$1.done"
}

verify_binary_type() {
  if ! command_exists "file"; then
    return
  fi

  BINARY_TYPE=$(file "$WORKSPACE/bin/ffmpeg" | sed -n 's/^.*\:\ \(.*$\)/\1/p')
  echo ""
  case $BINARY_TYPE in
  "Mach-O 64-bit executable arm64")
    echo "Successfully built Apple Silicon (M1) for ${OSTYPE}: ${BINARY_TYPE}"
    ;;
  *)
    echo "Successfully built binary for ${OSTYPE}: ${BINARY_TYPE}"
    ;;
  esac
}

cleanup() {
  remove_dir "$PACKAGES"
  remove_dir "$WORKSPACE"
  echo "Cleanup done."
  echo ""
}

usage() {
  echo "Usage: $PROGNAME [OPTIONS]"
  echo "Options:"
  echo "  -h, --help                     Display usage information"
  echo "      --version                  Display version information"
  echo "  -b, --build                    Starts the build process"
  echo "      --enable-gpl-and-non-free  Enable GPL and non-free codecs  - https://ffmpeg.org/legal.html"
  echo "  -c, --cleanup                  Remove all working dirs"
  echo "      --latest                   Build latest version of dependencies if newer available"
  echo "                                 Note: Because of the NSS (Name Service Switch), glibc does not recommend static links."
  echo ""
}

echo "ffmpeg-build-script v$SCRIPT_VERSION"
echo "========================="
echo ""

while (($# > 0)); do
  case $1 in
  -h | --help)
    usage
    exit 0
    ;;
  --version)
    echo "$SCRIPT_VERSION"
    exit 0
    ;;
  -*)
    if [[ "$1" == "--build" || "$1" =~ '-b' ]]; then
      bflag='-b'
    fi
    if [[ "$1" == "--enable-gpl-and-non-free" ]]; then
      CONFIGURE_OPTIONS+=("--enable-nonfree")
      CONFIGURE_OPTIONS+=("--enable-gpl")
      NONFREE_AND_GPL=true
    fi
    if [[ "$1" == "--cleanup" || "$1" =~ '-c' && ! "$1" =~ '--' ]]; then
      cflag='-c'
      cleanup
    fi
    if [[ "$1" == "--latest" ]]; then
      LATEST=true
    fi
    shift
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done

if [ -z "$bflag" ]; then
  if [ -z "$cflag" ]; then
    usage
    exit 1
  fi
  exit 0
fi

echo "Using $MJOBS make jobs simultaneously."

if $NONFREE_AND_GPL; then
echo "With GPL and non-free codecs"
fi

mkdir -p "$PACKAGES"
mkdir -p "$WORKSPACE"

export PATH="${WORKSPACE}/bin:$PATH"
PKG_CONFIG_PATH="${WORKSPACE}/lib/pkgconfig:${WORKSPACE}/lib64/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig"
PKG_CONFIG_PATH+=":/usr/local/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib64/pkgconfig"
export PKG_CONFIG_PATH

if ! command_exists "make"; then
  echo "make not installed."
  exit 1
fi

if ! command_exists "g++"; then
  echo "g++ not installed."
  exit 1
fi

if ! command_exists "curl"; then
  echo "curl not installed."
  exit 1
fi

if ! command_exists "cargo"; then
  echo "cargo not installed. rav1e encoder will not be available."
fi

if ! command_exists "python3"; then
  echo "python3 command not found. Lv2 filter and dav1d decoder will not be available."
fi

##
## build tools
##

if build "pkg-config" "0.29.2"; then
  download "https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz"
  execute ./configure --silent --prefix="${WORKSPACE}" --with-pc-path="${WORKSPACE}"/lib/pkgconfig --with-internal-glib
  execute make -j $MJOBS
  execute make install
  build_done "pkg-config" "0.29.2"
fi

if build "yasm" "1.3.0"; then
  download "https://github.com/yasm/yasm/releases/download/v1.3.0/yasm-1.3.0.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "yasm" "1.3.0"
fi

if build "nasm" "2.16.01"; then
  download "https://www.nasm.us/pub/nasm/releasebuilds/2.16.01/nasm-2.16.01.tar.xz"
  execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static
  execute make -j $MJOBS
  execute make install
  build_done "nasm" "2.16.01"
fi

if build "zlib" "1.2.13"; then
  download "https://www.zlib.net/zlib-1.2.13.tar.gz"
  execute ./configure --static --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "zlib" "1.2.13"
fi

if build "m4" "1.4.19"; then
  download "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "m4" "1.4.19"
fi

if build "autoconf" "2.71"; then
  download "https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "autoconf" "2.71"
fi

if build "automake" "1.16.5"; then
  download "https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.gz"
  execute ./configure --prefix="${WORKSPACE}"
  execute make -j $MJOBS
  execute make install
  build_done "automake" "1.16.4"
fi

if build "libtool" "2.4.7"; then
  download "https://ftpmirror.gnu.org/libtool/libtool-2.4.7.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --disable-static --enable-shared
  execute make -j $MJOBS
  execute make install
  build_done "libtool" "2.4.7"
fi

if build "cmake" "3.25.1"; then
  download "https://github.com/Kitware/CMake/releases/download/v3.25.1/cmake-3.25.1.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --parallel="${MJOBS}" -- -DCMAKE_USE_OPENSSL=OFF
  execute make -j $MJOBS
  execute make install
  build_done "cmake" "3.25.1"
fi

##
## video library
##

if build "libalsa" "1.2.7.2"; then
  download "https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.7.2.tar.bz2"
  execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static --enable-pic
  execute make -j $MJOBS
  execute make install
  build_done "libalsa" "1.2.7.2"
fi

if build "libvpx" "1.13.0"; then
  download "https://github.com/webmproject/libvpx/archive/refs/tags/v1.13.0.tar.gz" "libvpx-1.13.0.tar.gz"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Applying Darwin patch"
    sed "s/,--version-script//g" build/make/Makefile >build/make/Makefile.patched
    sed "s/-Wl,--no-undefined -Wl,-soname/-Wl,-undefined,error -Wl,-install_name/g" build/make/Makefile.patched >build/make/Makefile
  fi

  execute ./configure --prefix="${WORKSPACE}" --disable-unit-tests --enable-shared --as=yasm --enable-vp9-highbitdepth
  execute make -j $MJOBS
  execute make install

  build_done "libvpx" "1.13.0"
fi
CONFIGURE_OPTIONS+=("--enable-libvpx")

if $NONFREE_AND_GPL; then
  if build "xvidcore" "1.3.7"; then
    download "https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz"
    cd build/generic || exit
    execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static
    execute make -j $MJOBS
    execute make install

    if [[ -f ${WORKSPACE}/lib/libxvidcore.4.dylib ]]; then
      execute rm "${WORKSPACE}/lib/libxvidcore.4.dylib"
    fi

    if [[ -f ${WORKSPACE}/lib/libxvidcore.so ]]; then
      execute rm "${WORKSPACE}"/lib/libxvidcore.so*
    fi

    build_done "xvidcore" "1.3.7"
  fi
  CONFIGURE_OPTIONS+=("--enable-libxvid")
fi

#if build "zimg" "3.0.4"; then
#  download "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.4.tar.gz" "zimg-3.0.4.tar.gz" "zimg"
#  cd zimg-release-3.0.4 || exit
#  execute "${WORKSPACE}/bin/libtoolize" -i -f -q
#  execute ./autogen.sh --prefix="${WORKSPACE}"
#  execute ./configure --prefix="${WORKSPACE}" --disable-static --enable-shared
#  execute make -j $MJOBS
#  execute make install
#  build_done "zimg" "3.0.4"
#fi
#CONFIGURE_OPTIONS+=("--enable-libzimg")

if $NONFREE_AND_GPL; then

  if build "x264" "941cae6d"; then
    download "https://code.videolan.org/videolan/x264/-/archive/941cae6d1d6d6344c9a1d27440eaf2872b18ca9a/x264-941cae6d1d6d6344c9a1d27440eaf2872b18ca9a.tar.gz" "x264-941cae6d.tar.gz"
    cd "${PACKAGES}"/x264-941cae6d || exit

    execute ./configure --prefix="${WORKSPACE}" --host=arm-linux --enable-pic --extra-cflags="-mfpu=neon"

    execute make -j $MJOBS
    execute make install
    execute make install-lib-static

    build_done "x264" "941cae6d"
  fi
  CONFIGURE_OPTIONS+=("--enable-libx264")
fi

if build "lame" "3.100"; then
  download "https://sourceforge.net/projects/lame/files/lame/3.100/lame-3.100.tar.gz/download?use_mirror=gigenet" "lame-3.100.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static
  execute make -j $MJOBS
  execute make install

  build_done "lame" "3.100"
fi
CONFIGURE_OPTIONS+=("--enable-libmp3lame")

if build "libogg" "1.3.5"; then
  download "https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.5.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static
  execute make -j $MJOBS
  execute make install
  build_done "libogg" "1.3.5"
fi

if build "libvorbis" "1.3.7"; then
  download "https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.gz"
  execute ./configure --prefix="${WORKSPACE}" --with-ogg-libraries="${WORKSPACE}"/lib --with-ogg-includes="${WORKSPACE}"/include/ --disable-static --enable-shared --disable-oggtest
  execute make -j $MJOBS
  execute make install

  build_done "libvorbis" "1.3.7"
fi
CONFIGURE_OPTIONS+=("--enable-libvorbis")



if $NONFREE_AND_GPL; then
  if build "fdk_aac" "2.0.2"; then
    download "https://sourceforge.net/projects/opencore-amr/files/fdk-aac/fdk-aac-2.0.2.tar.gz/download?use_mirror=gigenet" "fdk-aac-2.0.2.tar.gz"
    execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static --enable-pic
    execute make -j $MJOBS
    execute make install

    build_done "fdk_aac" "2.0.2"
  fi
  CONFIGURE_OPTIONS+=("--enable-libfdk-aac")
fi

##
## image library
##

if build "libpng" "1.6.39"; then
  download "https://sourceforge.net/projects/libpng/files/libpng16/1.6.39/libpng-1.6.39.tar.gz/download?use_mirror=gigenet" "libpng-1.6.39.tar.gz"
  export LDFLAGS="${LDFLAGS}"
  export CPPFLAGS="${CFLAGS}"
  execute ./configure --prefix="${WORKSPACE}" --enable-shared --disable-static
  execute make -j $MJOBS
  execute make install
  build_done "libpng" "1.6.39"
fi

##
## HWaccel library
##

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  CONFIGURE_OPTIONS+=("--target-os=linux")
  if command_exists "nvcc"; then
    if build "nv-codec" "11.1.5.2"; then
      download "https://github.com/FFmpeg/nv-codec-headers/releases/download/n11.1.5.2/nv-codec-headers-11.1.5.2.tar.gz"
      execute make PREFIX="${WORKSPACE}"
      execute make install PREFIX="${WORKSPACE}"
      build_done "nv-codec" "11.1.5.2"
    fi
    CFLAGS+=" -I/usr/local/cuda/include"
    LDFLAGS+=" -L/usr/local/cuda/lib64"
    CONFIGURE_OPTIONS+=("--enable-cuda-nvcc" "--enable-cuvid" "--enable-nvenc" "--enable-cuda-llvm")

    if [ -z "$LDEXEFLAGS" ]; then
      CONFIGURE_OPTIONS+=("--enable-libnpp") # Only libnpp cannot be statically linked.
    fi

    # https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
    CONFIGURE_OPTIONS+=("--nvccflags=-gencode arch=compute_52,code=sm_52")
  fi

  # Vaapi doesn't work well with static links FFmpeg.
  if [ -z "$LDEXEFLAGS" ]; then
    # If the libva development SDK is installed, enable vaapi.
    if library_exists "libva"; then
      if build "vaapi" "1"; then
        build_done "vaapi" "1"
      fi
      CONFIGURE_OPTIONS+=("--enable-vaapi")
    fi
  fi

  if build "amf" "1.4.29"; then
    download "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/archive/refs/tags/v.1.4.29.tar.gz" "AMF-1.4.29.tar.gz" "AMF-1.4.29"
    execute rm -rf "${WORKSPACE}/include/AMF"
    execute mkdir -p "${WORKSPACE}/include/AMF"
    execute cp -r "${PACKAGES}"/AMF-1.4.29/AMF-v.1.4.29/amf/public/include/* "${WORKSPACE}/include/AMF/"
    build_done "amf" "1.4.29.0"
  fi
  CONFIGURE_OPTIONS+=("--enable-amf")
fi

##
## FFmpeg
##

EXTRA_VERSION=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  EXTRA_VERSION="${FFMPEG_VERSION}"
fi

build "ffmpeg" "$FFMPEG_VERSION"
download "https://github.com/FFmpeg/FFmpeg/archive/refs/heads/release/$FFMPEG_VERSION.tar.gz" "FFmpeg-release-$FFMPEG_VERSION.tar.gz"

echo "cflags: ${CFLAGS}"
echo "configure: ${CONFIGURE_OPTIONS}"

mparam=" -m64"
mparam=""
CONFIGURE_OPTIONS+=("--arch=armhf")
CONFIGURE_OPTIONS+=("--enable-neon")
#case $(arch) in
#	'aarch64' | 'arm64')
#		mparam=""
#		CONFIGURE_OPTIONS+=("--arch=aarch64")
#		CONFIGURE_OPTIONS+=("--enable-neon")
#		CONFIGURE_OPTIONS+=("--enable-v4l2-m2m")
#		if [ "$isBuster" = true ]; then
#			echo "Adding OMX (Buster)"
#			CONFIGURE_OPTIONS+=("--enable-omx")
#			CONFIGURE_OPTIONS+=("--enable-omx-rpi")
#		fi
		#CONFIGURE_OPTIONS+=("--enable-mmal") -- not available on 64 bit pi's		
#	;;
#	'arm' | 'armv6l' | 'armv7l')
#		mparam=""
#		CONFIGURE_OPTIONS+=("--arch=armel")
#	;;
#esac


# shellcheck disable=SC2086
./configure "${CONFIGURE_OPTIONS[@]}" \
  --disable-debug \
  --disable-doc \
  --enable-shared \
  --enable-pthreads \
  --enable-small \
  --enable-version3 \
  --enable-hwaccels \
  --enable-hardcoded-tables \
  --extra-cflags="-fPIC ${mparam} ${CFLAGS}" \
  --extra-ldexeflags="${LDEXEFLAGS}" \
  --extra-ldflags="${LDFLAGS}" \
  --extra-ldsoflags="-Wl,-rpath,$WORKSPACE/lib" \
  --extra-libs="${EXTRALIBS}" \
  --pkgconfigdir="$WORKSPACE/lib/pkgconfig" \
  --pkg-config-flags="--static" \
  --prefix="${WORKSPACE}" \
  --extra-version="${EXTRA_VERSION}"

execute make -j $MJOBS
execute make install

verify_binary_type

exit 0
