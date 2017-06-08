SHELL=/bin/bash

DEBUG=0

IMAGE_NAME=device-path
# Megabytes.
IMAGE_SIZE=200

DISK=/dev/loop0
MNT=mnt

FILE_NAME=main

SHELL_EFI=Shell.efi

GNU_EFI=gnu-efi
GNU_EFI_TAG=3.0.5
GNU_EFI_INC=${GNU_EFI}/inc

ARCH=x86_64

CFLAGS=-fno-stack-protector \
       -fpic \
       -fshort-wchar \
       -mno-red-zone \
       -Wall \
       -Wextra \
       -I${GNU_EFI_INC} -I${GNU_EFI_INC}/${ARCH} -I${GNU_EFI_INC}/protocol
ifeq (${ARCH},x86_64)
CFLAGS+=-DEFI_FUNCTION_WRAPPER
endif
ifeq (${DEBUG},1)
CFLAGS+=-ggdb -DDEBUG_LOOP
endif

LFLAGS=${GNU_EFI}/${ARCH}/gnuefi/crt0-efi-${ARCH}.o \
       -nostdlib \
       -znocombreloc \
       -T ${GNU_EFI}/gnuefi/elf_${ARCH}_efi.lds \
       -shared \
       -Bsymbolic \
       -L ${GNU_EFI}/${ARCH}/gnuefi \
       -L ${GNU_EFI}/${ARCH}/lib \
       -l efi \
       -l gnuefi

OCFLAGS= -j .text \
	 -j .sdata \
	 -j .data \
	 -j .dynamic \
	 -j .dynsym \
	 -j .rel \
	 -j .rela \
	 -j .reloc \
	 --target=efi-app-${ARCH}


.PHONY: all fetch-shell fetch-gnu-efi build-gnu-efi build image umount detach convert clean

all: | fetch-shell fetch-gnu-efi build-gnu-efi build image umount detach convert

fetch-shell:
	curl -o ${SHELL_EFI} https://raw.githubusercontent.com/tianocore/edk2/master/ShellBinPkg/UefiShell/X64/Shell.efi

fetch-gnu-efi:
	git clone https://git.code.sf.net/p/gnu-efi/code ${GNU_EFI}
	cd ${GNU_EFI} ; git checkout ${GNU_EFI_TAG}

build-gnu-efi:
	make -C ${GNU_EFI}

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
	sudo cp ${SHELL_EFI} ${MNT}/EFI/BOOT/BOOTX64.efi
	sudo cp ${FILE_NAME}.efi ${MNT}/EFI/BOOT/

build:
	gcc ${FILE_NAME}.c -c ${CFLAGS} -o ${FILE_NAME}.o
	ld ${FILE_NAME}.o ${LFLAGS} -o ${FILE_NAME}.so
	objcopy ${OCFLAGS} ${FILE_NAME}.so ${FILE_NAME}.efi
ifeq (${DEBUG},1)
	objcopy ${OCFLAGS} \
	  -j .debug_info \
	  -j .debug_abbrev \
	  -j .debug_loc \
	  -j .debug_aranges \
	  -j .debug_line \
	  -j .debug_macinfo \
	  -j .debug_str \
	  ${FILE_NAME}.so ${FILE_NAME}_debug.efi
endif

umount:
	sudo umount ${MNT}

detach:
	sudo losetup -d ${DISK}

convert:
	qemu-img convert -f raw -O vmdk ${IMAGE_NAME}.raw ${IMAGE_NAME}.vmdk

clean:
	rm -rf ${IMAGE_NAME}.{raw,vmdk} ${FILE_NAME}{.efi,_debug.efi,.o,.so}
