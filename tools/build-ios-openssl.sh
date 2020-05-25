#!/bin/bash
#
# Copyright 2016 leenjewel
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# read -n1 -p "Press any key to continue..."

set -u

TOOLS_ROOT=$(pwd)

SOURCE="$0"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
pwd_path="$(cd -P "$(dirname "$SOURCE")" && pwd)"

echo pwd_path=${pwd_path}
echo TOOLS_ROOT=${TOOLS_ROOT}

IOS_MIN_TARGET="8.0"
# openssl-1.1.0f has a configure bug
# openssl-1.1.1d has fix configure bug
LIB_VERSION="OpenSSL_1_1_1d"
LIB_NAME="openssl-1.1.1d"
LIB_DEST_DIR="${pwd_path}/../output/ios/openssl-universal"
HEADER_DEST_DIR="include"

# Setup architectures, library name and other vars + cleanup from previous runs
# ARCHS=("arm64" "armv7s" "armv7" "i386" "x86_64")
# SDKS=("iphoneos" "iphoneos" "iphoneos" "iphonesimulator" "iphonesimulator")
# PLATFORMS=("iPhoneOS" "iPhoneOS" "iPhoneOS" "iPhoneSimulator" "iPhoneSimulator")

ARCHS=("armv7" "arm64" "x86_64")
SDKS=("iphoneos" "iphoneos" "iphonesimulator")
PLATFORMS=("iPhoneOS" "iPhoneOS" "iPhoneSimulator")

# ARCHS=("x86_64")
# SDKS=("iphonesimulator")
# PLATFORMS=("iPhoneSimulator")

echo "https://www.openssl.org/source/${LIB_NAME}.tar.gz"

# https://github.com/openssl/openssl/archive/OpenSSL_1_1_1d.tar.gz
# https://github.com/openssl/openssl/archive/OpenSSL_1_1_1f.tar.gz
DEVELOPER=$(xcode-select -print-path)
SDK_VERSION=$(xcrun -sdk iphoneos --show-sdk-version)
rm -rf "${HEADER_DEST_DIR}" "${LIB_DEST_DIR}" "${LIB_NAME}"
[ -f "${LIB_NAME}.tar.gz" ] || curl https://www.openssl.org/source/${LIB_NAME}.tar.gz >${LIB_NAME}.tar.gz

configure_make() {

    ARCH=$1
    SDK=$2
    PLATFORM=$3

    echo "configure $ARCH start..."

    if [ -d "${LIB_NAME}" ]; then
        rm -fr "${LIB_NAME}"
    fi
    tar xfz "${LIB_NAME}.tar.gz"
    pushd .
    cd "${LIB_NAME}"

    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
        echo ""
    else
        sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
    fi

    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}${SDK_VERSION}.sdk"

    if [ ! -d ${CROSS_TOP}/SDKs/${CROSS_SDK} ]; then
        echo "ERROR: iOS SDK version:'${SDK_VERSION}' incorrect, SDK in your system is:"
        xcodebuild -showsdks | grep iOS
        exit -1
    fi

    PREFIX_DIR="${pwd_path}/../output/ios/openssl-${ARCH}"
    if [ -d "${PREFIX_DIR}" ]; then
        rm -fr "${PREFIX_DIR}"
    fi
    mkdir -p "${PREFIX_DIR}"

    unset IPHONEOS_DEPLOYMENT_TARGET

    if [[ "${ARCH}" == "x86_64" ]]; then

        export CC="xcrun -sdk iphonesimulator clang -arch x86_64"
        export CXX="xcrun -sdk iphonesimulator clang++ -arch x86_64"
        export CFLAGS="-arch x86_64 -target x86_64-ios-darwin -march=x86-64 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_TARGET} -I${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/include"

        # openssl1.1.1d can be set normally, 1.1.0f does not take effect
        export LDFLAGS="-arch x86_64 -target x86_64-ios-darwin -march=x86-64 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/lib"

        ./Configure darwin64-x86_64-cc no-shared --prefix="${PREFIX_DIR}"

    elif [[ "${ARCH}" == "armv7" ]]; then

        export CC="xcrun -sdk iphoneos clang -arch armv7"
        export CXX="xcrun -sdk iphoneos clang++ -arch armv7"
        export CFLAGS="-arch armv7 -target armv7-ios-darwin -march=armv7 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -fembed-bitcode -miphoneos-version-min=${IOS_MIN_TARGET} -I${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/include"

        # openssl1.1.1d can be set normally, 1.1.0f does not take effect
        export LDFLAGS="-arch armv7 -target armv7-ios-darwin -march=armv7 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -fembed-bitcode -L${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/lib"

        ./Configure iphoneos-cross no-shared --prefix="${PREFIX_DIR}"
        sed -ie "s!-fno-common!-fno-common -fembed-bitcode !" "Makefile"

    elif [[ "${ARCH}" == "arm64" ]]; then

        export CC="xcrun -sdk iphoneos clang -arch arm64"
        export CXX="xcrun -sdk iphoneos clang++ -arch arm64"
        export CFLAGS="-arch arm64 -target aarch64-ios-darwin -march=armv8 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -fembed-bitcode -miphoneos-version-min=${IOS_MIN_TARGET} -I${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/include"

        # openssl1.1.1d can be set normally, 1.1.0f does not take effect
        export LDFLAGS="-arch arm64 -target aarch64-ios-darwin -march=armv8 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -fembed-bitcode -L${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/lib"

        ./Configure iphoneos-cross no-shared --prefix="${PREFIX_DIR}"
        sed -ie "s!-fno-common!-fno-common -fembed-bitcode !" "Makefile"

    else
        echo "not support" && exit 1
    fi

    if [ ! -d ${CROSS_TOP}/SDKs/${CROSS_SDK} ]; then
        echo "ERROR: iOS SDK version:'${SDK_VERSION}' incorrect, SDK in your system is:"
        xcodebuild -showsdks | grep iOS
        exit -1
    fi

    OUTPUT_ROOT=${TOOLS_ROOT}/../output/ios/openssl-${ARCH}
    mkdir -p ${OUTPUT_ROOT}/log

    echo "make $ARCH start..."

    make clean &>"${OUTPUT_ROOT}/log/${ARCH}.log"
    if make -j8 >>"${OUTPUT_ROOT}/log/${ARCH}.log" 2>&1; then
        make install_sw >>"${OUTPUT_ROOT}/log/${ARCH}.log" 2>&1
        make install_ssldirs >>"${OUTPUT_ROOT}/log/${ARCH}.log" 2>&1
    fi

    popd
}

for ((i = 0; i < ${#ARCHS[@]}; i++)); do
    if [[ $# -eq 0 || "$1" == "${ARCHS[i]}" ]]; then
        configure_make "${ARCHS[i]}" "${SDKS[i]}" "${PLATFORMS[i]}"
    fi
done

echo "lipo start..."

create_lib() {
    LIB_SRC=$1
    LIB_DST=$2
    LIB_PATHS=("${ARCHS[@]/#/${pwd_path}/../output/ios/openssl-}")
    LIB_PATHS=("${LIB_PATHS[@]/%//lib/${LIB_SRC}}")
    lipo ${LIB_PATHS[@]} -create -output "${LIB_DST}"
}
mkdir -p "${LIB_DEST_DIR}"
create_lib "libcrypto.a" "${LIB_DEST_DIR}/libcrypto-universal.a"
create_lib "libssl.a" "${LIB_DEST_DIR}/libssl-universal.a"

echo "buil ios openssl end..."
