./configure --prefix=${PREFIX} \
    --oldincludedir=${BUILD_PREFIX}/${HOST}/sysroot/usr/include \
    --enable-shared

make -j${CPU_COUNT}
make install