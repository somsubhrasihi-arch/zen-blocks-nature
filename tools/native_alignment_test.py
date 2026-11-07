import io
import struct
import unittest
import zipfile
from check_native_alignment import check_bundle, load_segments


def elf(alignment=16384, offset=0, address=0):
    data = bytearray(120)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, 1)
    struct.pack_into('<I', data, 64, 1)
    struct.pack_into('<QQ', data, 72, offset, address)
    struct.pack_into('<Q', data, 112, alignment)
    return bytes(data)


class NativeAlignmentTest(unittest.TestCase):
    def test_accepts_16k_and_larger(self):
        self.assertEqual(load_segments(elf()), [16384])
        self.assertEqual(load_segments(elf(65536)), [65536])

    def test_rejects_4k_and_invalid_headers(self):
        for data in (elf(4096), elf(20000), elf(16384, 1, 0), b'not an ELF', elf()[:80]):
            with self.subTest(length=len(data)):
                with self.assertRaises(ValueError):
                    load_segments(data)

    def test_bundle_checks_64_bit_libraries(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('base/lib/arm64-v8a/libflutter.so', elf())
            archive.writestr('base/lib/x86_64/libapp.so', elf(65536))
            archive.writestr('base/lib/armeabi-v7a/libapp.so', b'32-bit excluded')
        data.seek(0)
        self.assertEqual(len(check_bundle(data)['checkedLibraries']), 2)

    def test_empty_bundle_is_not_a_pass(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w'):
            pass
        data.seek(0)
        with self.assertRaises(ValueError):
            check_bundle(data)


if __name__ == '__main__':
    unittest.main()
