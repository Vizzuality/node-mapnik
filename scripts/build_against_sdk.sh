#!/usr/bin/env bash
set -u -e

: '
On linux depends on node and:

    sudo apt-get update
    sudo apt-get install pkg-config build-essential zlib1g-dev
'

ARGS=""
CURRENT_DIR="$( cd "$( dirname $BASH_SOURCE )" && pwd )"
mkdir -p $CURRENT_DIR/../sdk
cd $CURRENT_DIR/../
export PATH=$(pwd)/node_modules/.bin:${PATH}
cd sdk
BUILD_DIR="$(pwd)"
UNAME=$(uname -s);

if [[ ${1:-false} != false ]]; then
    ARGS=$1
fi

function upgrade_gcc {
    echo "adding gcc-4.8 ppa"
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    echo "updating apt"
    sudo apt-get update -y -qq
    echo "installing C++11 compiler"
    sudo apt-get install -y gcc-4.8 g++-4.8
    if [[ "${CXX#*'clang'}" == "$CXX" ]]; then
        export CC="gcc-4.8"
        export CXX="g++-4.8"
    fi
}

COMPRESSION="tar.bz2"
SDK_URI="http://mapnik.s3.amazonaws.com/dist/dev"
platform=$(echo $UNAME | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/")

if [[ "${CXX11:-false}" != false ]]; then
    # mapnik 3.x / c++11 enabled
    HASH="1667-g8cfb49d"
    if [[ ${platform} == 'linux' ]]; then
        upgrade_gcc
    fi
else
    # mapnik 2.3.x / c++11 not enabled
    HASH="577-ga616e9d"
fi

if [[ $platform == 'darwin' ]]; then
    platform="macosx"
fi

TARBALL_NAME="mapnik-${platform}-sdk-v2.2.0-${HASH}"
REMOTE_URI="${SDK_URI}/${TARBALL_NAME}.${COMPRESSION}"
export MAPNIK_SDK=${BUILD_DIR}/${TARBALL_NAME}
export PATH=${MAPNIK_SDK}/bin:${PATH}
export PKG_CONFIG_PATH=${MAPNIK_SDK}/lib/pkgconfig

echo "looking for ~/projects/mapnik-packaging/osx/out/dist/${TARBALL_NAME}.${COMPRESSION}"
if [ -f "$HOME/projects/mapnik-packaging/osx/out/dist/${TARBALL_NAME}.${COMPRESSION}" ]; then
    echo "copying over ${TARBALL_NAME}.${COMPRESSION}"
    cp "$HOME/projects/mapnik-packaging/osx/out/dist/${TARBALL_NAME}.${COMPRESSION}" .
else
    if [ ! -f "${TARBALL_NAME}.${COMPRESSION}" ]; then
        echo "downloading ${REMOTE_URI}"
        curl -f -o "${TARBALL_NAME}.${COMPRESSION}" "${REMOTE_URI}"
    fi
fi

if [ ! -d ${TARBALL_NAME} ]; then
    echo "unpacking ${TARBALL_NAME}"
    tar xf ${TARBALL_NAME}.${COMPRESSION}
fi

if [[ ! `which pkg-config` ]]; then
    echo 'pkg-config not installed'
    exit 1
fi

if [[ ! `which node` ]]; then
    echo 'node not installed'
    exit 1
fi

if [[ $UNAME == 'Linux' ]]; then
    readelf -d $MAPNIK_SDK/lib/libmapnik.so
    #sudo apt-get install chrpath -y
    #chrpath -r '$ORIGIN/' ${MAPNIK_SDK}/lib/libmapnik.so
    export LDFLAGS='-Wl,-z,origin -Wl,-rpath=\$$ORIGIN'
else
    otool -L $MAPNIK_SDK/lib/libmapnik.dylib
fi

cd ../
npm install node-pre-gyp
MODULE_PATH=$(node-pre-gyp reveal module_path ${ARGS})
# note: dangerous!
rm -rf ${MODULE_PATH}
npm install --build-from-source ${ARGS} --clang=1
npm ls
# copy lib
cp ${MAPNIK_SDK}/lib/libmapnik.* ${MODULE_PATH}
# copy plugins
cp -r ${MAPNIK_SDK}/lib/mapnik ${MODULE_PATH}
# copy share data
mkdir -p ${MODULE_PATH}/share/
cp -r ${MAPNIK_SDK}/share/mapnik ${MODULE_PATH}/share/
# generate new settings
echo "
var path = require('path');
module.exports.paths = {
    'fonts': path.join(__dirname, 'mapnik/fonts'),
    'input_plugins': path.join(__dirname, 'mapnik/input')
};
module.exports.env = {
    'ICU_DATA': path.join(__dirname, 'share/mapnik/icu'),
    'GDAL_DATA': path.join(__dirname, 'share/mapnik/gdal'),
    'PROJ_LIB': path.join(__dirname, 'share/mapnik/proj')
};
" > ${MODULE_PATH}/mapnik_settings.js

# cleanup
rm -rf $BUILD_DIR
