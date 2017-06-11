import os

fname = 'DevicePath.debug'

gdb.execute('set disassembly-flavor intel')
# set pagination off
# layout split

gdb.execute('file Shell.efi')
gdb.execute('target remote 192.168.0.197:8186')

gdb.execute('cont')

# add-symbols 0xffff
class AddSymbols(gdb.Command):
    def __init__(self):
        super(AddSymbols, self).__init__("add-symbols", gdb.COMMAND_USER)

    def invoke(self, base, _):
        base = int(base, 16)
        str = os.popen("readelf --sections %s" % fname).read()

        text = None
        data = None

        def sec_addr(line):
            return int(line.strip().split()[4], 16)

        for line in str.split('\n'):
            if ' .text' in line:
                text = sec_addr(line)
            elif ' .data' in line:
                data = sec_addr(line)

        if not text:
            print("Failed to find text")
            exit(1)

        if not data:
            print("Failed to find data")
            exit(1)

        text += base
        data += base

        gdb.execute(
            'add-symbol-file %s 0x%x -s .data 0x%x' % (fname, text, data))

AddSymbols()
