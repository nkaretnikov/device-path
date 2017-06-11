A sample UEFI program that prints device paths of removable media.

Note: EDK2 includes an emulator (see edk2/EmulatorPkg/README), but
I couldn't make it work.  On both Fedora and Ubuntu, it just segfaults when gdb
starts (tested on UDK2017 and b941c34ef859971e29683ffb57c309e24e6a96be).
So I'm using the following setup, which also works with gnu-efi.

# Debugging with VMware Fusion

Create a Linux debugger VM and build the project: `make DEBUG=1`.

Create a debuggee VM using the .vmdk file and add these options to its .vmx
file:
```
firmware="efi"
debugStub.listen.guest64 = "TRUE"
debugStub.listen.guest64.remote = "TRUE"
debugStub.port.guest64 = "8186"
debugStub.listen.guest32 = "TRUE"
debugStub.listen.guest32.remote = "TRUE"
debugStub.port.guest32 = "8132"
#debugStub.hideBreakpoints= "TRUE"
```

Start the debuggee VM and connect to it from the debugger VM:
```
$ gdb -q -x gdb.py
```

Start the application in the debuggee VM:
```
fs0:
cd EFI\BOOT
DevicePath.efi
```

Add symbols in gdb by specifying the printed image base address.
For example:
```
Ctrl-C
(gdb) add-symbols 0xcfa4000
(gdb) layout split
(gdb) set Wait = 0   # stop the debug loop
```
(For more information: http://wiki.osdev.org/Debugging_UEFI_applications_with_GDB)

Continue debugging.
