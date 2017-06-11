SHELL=/bin/bash

# Fails to build in a shared folder.
EDK2=${HOME}/edk2
EDK2_TAG=b941c34ef859971e29683ffb57c309e24e6a96be

IMAGE_NAME=device-path
# Megabytes.
IMAGE_SIZE=200

DISK=/dev/loop0
MNT=mnt
SHELL_EFI=Shell.efi

FILE_NAME=DevicePath
MODULE=MdeModule
PKG=${MODULE}Pkg
DSC=${PKG}/${PKG}.dsc
APP_DIR=${PKG}/Application/${FILE_NAME}
BUILD_DIR=${EDK2}/Build/${MODULE}/${TARGET}_${TOOLCHAIN}/${ARCH}
INF=${PKG}/Application/${FILE_NAME}/${FILE_NAME}.inf
TOOLCHAIN=GCC5
ARCH=X64
DEBUG=0
ifeq (${DEBUG},1)
DEFINES=-D DEBUG_LOOP
endif
#TARGET=DEBUG
TARGET=RELEASE
DSC_STR=\
\ \ ${INF}\ {\n\
\ \ \ <BuildOptions>\n\
\ \ \ \ \ !IFDEF\ $$(DEBUG_LOOP)\n\
\ \ \ \ \ \ \ GCC\:\ *_*_*_CC_FLAGS\ =\ -D\ DEBUG_LOOP\n\
\ \ \ \ \ !ENDIF\n\
\ }

.PHONY: all fetch-shell fetch-edk2 build-edk2 build image umount detach convert clean

all: | fetch-shell fetch-edk2 build-edk2 build image umount detach convert

fetch-shell:
	curl -o ${SHELL_EFI} https://raw.githubusercontent.com/tianocore/edk2/master/ShellBinPkg/UefiShell/X64/Shell.efi

fetch-edk2:
	git clone https://github.com/tianocore/edk2 ${EDK2}
	cd ${EDK2} ; git checkout ${EDK2_TAG}

build-edk2:
	sudo yum groupinstall development-tools
	sudo yum install iasl libuuid-devel python gcc-c++ nasm \
	  libX11-devel libXtst-devel
	# sudo dnf debuginfo-install glibc libX11 libXau libxcb libXext
	make -C ${EDK2}/BaseTools

build:
	mkdir -p ${EDK2}/${APP_DIR}
	cp ${FILE_NAME}.{inf,c} ${EDK2}/${APP_DIR}
	if ! grep ${INF} ${EDK2}/${DSC} ; then \
	    sed -i '/\[Components\]/a${DSC_STR}' ${EDK2}/${DSC} ; \
	fi
	cd ${EDK2} ; . edksetup.sh ; \
	    build -p ${DSC} -b ${TARGET} -a ${ARCH} -t ${TOOLCHAIN} \
                -m ${INF} ${DEFINES}

image:
	dd if=/dev/zero of=${IMAGE_NAME}.raw bs=1M count=${IMAGE_SIZE}
	sudo losetup ${DISK} ${IMAGE_NAME}.raw
	sudo parted -s ${DISK} \
	  'mklabel gpt' \
	  'mkpart primary 0 -1' \
	  'set 1 esp on' \
	  'print' \
	  'quit'
	sudo mkfs.vfat ${DISK}p1
	sudo mkdir -p ${MNT}
	sudo mount ${DISK}p1 ${MNT}
	sudo mkdir -p ${MNT}/EFI/BOOT
	sudo cp ${SHELL_EFI} ${MNT}/EFI/BOOT/BOOT${ARCH}.efi
	sudo cp ${BUILD_DIR}/${FILE_NAME}.efi ${MNT}/EFI/BOOT/
	sudo cp ${BUILD_DIR}/${FILE_NAME}.debug .

umount:
	sudo umount ${MNT}

detach:
	sudo losetup -d ${DISK}

convert:
	qemu-img convert -f raw -O vmdk ${IMAGE_NAME}.raw ${IMAGE_NAME}.vmdk

clean:
	rm -rf ${IMAGE_NAME}.{raw,vmdk} ${FILE_NAME}.debug
