#include <Library/DevicePathLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>
#include <Protocol/BlockIo.h>
#include <Protocol/DevicePath.h>
#include <Protocol/LoadedImage.h>

EFI_STATUS
EFIAPI
UefiMain (
    IN EFI_HANDLE        ImageHandle,
    IN EFI_SYSTEM_TABLE  *SystemTable
    )
{
    EFI_STATUS Status;

#ifdef DEBUG_LOOP
    EFI_LOADED_IMAGE *LoadedImage = NULL;
    EFI_GUID         LoadedImageProtocol = LOADED_IMAGE_PROTOCOL;

    Status = gBS->HandleProtocol(ImageHandle,
                                 &LoadedImageProtocol,
                                 (VOID**)&LoadedImage);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to handle LOADED_IMAGE_PROTOCOL: %r\n", Status);
        return Status;
    }

    Print(L"Image base: 0x%lx\n", LoadedImage->ImageBase);

    volatile int Wait = 1;
    while (Wait) {
        __asm__ __volatile__("pause");
    }
#endif

    EFI_GUID   BlockIoProtocol = BLOCK_IO_PROTOCOL;
    UINTN      NoHandles;
    EFI_HANDLE *Handles;
    UINTN      Index;

    Status = gBS->LocateHandleBuffer(ByProtocol,
                                     &BlockIoProtocol,
                                     NULL,
                                     &NoHandles,
                                     &Handles);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to locate BLOCK_IO_PROTOCOL: %r\n", Status);
        return Status;
    }

    for (Index = 0; Index < NoHandles; ++Index) {
        EFI_DEVICE_PATH *DevicePath = NULL;
        EFI_GUID        DevicePathProtocol = DEVICE_PATH_PROTOCOL;

        Status = gBS->HandleProtocol(Handles[Index],
                                     &DevicePathProtocol,
                                     (VOID**)&DevicePath);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to handle DEVICE_PATH_PROTOCOL: %r\n", Status);
            return Status;
        }

        EFI_BLOCK_IO *BlockIo = NULL;

        Status = gBS->HandleProtocol(Handles[Index],
                                     &BlockIoProtocol,
                                     (VOID**)&BlockIo);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to handle BLOCK_IO_PROTOCOL: %r\n", Status);
            return Status;
        }

        if (BlockIo->Media->RemovableMedia) {
            CHAR16* Str = ConvertDevicePathToText(DevicePath, TRUE, TRUE);
            Print(L"%s\n", Str);
            FreePool(Str);
        }
    }

    return Status;
}
