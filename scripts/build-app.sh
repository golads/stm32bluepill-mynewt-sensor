#!/usr/bin/env bash
#  Build application

set -e  #  Exit when any command fails.
set -x  #  Echo all commands.

#  Delete the compiled image so that the build script will relink the Rust app with the C libraries.
if [ -e bin/targets/bluepill_my_sensor/app/apps/my_sensor_app/my_sensor_app.elf ]; then
    rm bin/targets/bluepill_my_sensor/app/apps/my_sensor_app/my_sensor_app.elf
fi

#  Build the Rust app in "src" folder.
cargo build -v

#  Export the metadata for the Rust build.
cargo metadata --format-version 1 >logs/libmylib.json

#  Create rustlib, the library that contains the compiled Rust app and its dependencies (except libcore).  Create in temp folder named "tmprustlib"
if [ -d tmprustlib ]; then
    rm -r tmprustlib
fi
if [ ! -d tmprustlib ]; then
    mkdir tmprustlib
fi
pushd tmprustlib

#  Extract the object (*.o) files in the compiled Rust output (*.rlib).
FILES=../target/thumbv7m-none-eabi/debug/deps/*.rlib
for f in $FILES
do
    arm-none-eabi-ar x $f
done

#  Archive the object (*.o) files into rustlib.a.
arm-none-eabi-ar r rustlib.a *.o

#  Overwrite libs_rust_app.a in the Mynewt build by rustlib.a.  libs_rust_app.a was originally created from libs/rust_app.
if [ -e ../bin/targets/bluepill_my_sensor/app/libs/rust_app/libs_rust_app.a ]; then
    cp rustlib.a ../bin/targets/bluepill_my_sensor/app/libs/rust_app/libs_rust_app.a
    touch ../bin/targets/bluepill_my_sensor/app/libs/rust_app/libs_rust_app.a
fi

#  Dump the ELF and disassembly for the compiled Rust application and libraries (except libcore)
arm-none-eabi-objdump -t -S            --line-numbers --wide rustlib.a >../logs/rustlib.S 2>&1
arm-none-eabi-objdump -t -S --demangle --line-numbers --wide rustlib.a >../logs/rustlib-demangle.S 2>&1

popd

#  Copy Rust libcore.
if [ -e bin/targets/bluepill_my_sensor/app/libs/rust_libcore/libs_rust_libcore.a ]; then

    if [ -e $HOME/.rustup/toolchains/nightly-2019-05-22-x86_64-apple-darwin/lib/rustlib/thumbv7m-none-eabi/lib/libcore-e6b0ad9835323d10.rlib ]; then
        cp $HOME/.rustup/toolchains/nightly-2019-05-22-x86_64-apple-darwin/lib/rustlib/thumbv7m-none-eabi/lib/libcore-e6b0ad9835323d10.rlib bin/targets/bluepill_my_sensor/app/libs/rust_libcore/libs_rust_libcore.a 
    fi
    touch bin/targets/bluepill_my_sensor/app/libs/rust_libcore/libs_rust_libcore.a 
fi

#  Dump the ELF and disassembly for the compiled Rust application.
set +e
arm-none-eabi-readelf -a --wide target/thumbv7m-none-eabi/debug/libmylib.rlib >logs/libmylib.elf 2>&1
arm-none-eabi-objdump -t -S            --line-numbers --wide target/thumbv7m-none-eabi/debug/libmylib.rlib >logs/libmylib.S 2>&1
arm-none-eabi-objdump -t -S --demangle --line-numbers --wide target/thumbv7m-none-eabi/debug/libmylib.rlib >logs/libmylib-demangle.S 2>&1
set -e

#  Run the Mynewt build, which will link with the Rust app, Rust libraries and libcore.
#  For verbose build: newt build -v -p bluepill_my_sensor
newt build bluepill_my_sensor

#  Display the image size.
newt size -v bluepill_my_sensor
