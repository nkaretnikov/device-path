#include <efi.h>
#include <efilib.h>

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_STATUS Status;

    InitializeLib(ImageHandle, SystemTable);

#ifdef DEBUG_LOOP
    EFI_LOADED_IMAGE *LoadedImage = NULL;
    EFI_GUID         LoadedImageProtocol = LOADED_IMAGE_PROTOCOL;

    Status = uefi_call_wrapper(BS->HandleProtocol,
                               3,
                               ImageHandle,
                               &LoadedImageProtocol,
                               (VOID**)&LoadedImage);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to handle LOADED_IMAGE_PROTOCOL: %r\n", Status);
        return Status;
    }

    Print(L"Image base: 0x%lx\n", LoadedImage->ImageBase);

    int Wait = 1;
    while (Wait) {
        __asm__ __volatile__("pause");
    }
#endif

    EFI_GUID   BlockIOProtocol = BLOCK_IO_PROTOCOL;
    UINTN      NoHandles;
    EFI_HANDLE *Handles;
    UINTN      Index;

    Status = LibLocateHandle(ByProtocol,
                             &BlockIOProtocol,
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

        Status = uefi_call_wrapper(BS->HandleProtocol,
                                   3,
                                   Handles[Index],
                                   &DevicePathProtocol,
                                   (VOID**)&DevicePath);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to handle DEVICE_PATH_PROTOCOL: %r\n", Status);
            return Status;
        }

        EFI_BLOCK_IO *BlockIo = NULL;
        EFI_GUID     BlockIoProtocol = BLOCK_IO_PROTOCOL;

        Status = uefi_call_wrapper(BS->HandleProtocol,
                                   3,
                                   Handles[Index],
                                   &BlockIoProtocol,
                                   (VOID**)&BlockIo);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to handle BLOCK_IO_PROTOCOL: %r\n", Status);
            return Status;
        }

        if (BlockIo->Media->RemovableMedia) {
            CHAR16* Str = DevicePathToStr(DevicePath);
            Print(L"%s\n", Str);
            FreePool(Str);
        }
    }

    return Status;
}
