"""Check 64-bit PT_LOAD segments in an Android bundle without extra dependencies.

This checks ELF alignment, not final APK zip alignment or runtime compatibility.
The release must still be tested on a 16 KB Android environment through Play.
"""
import argparse
import json
from pathlib import Path
import struct
import zipfile

PAGE_SIZE = 16384


def load_segments(data):
    if len(data) < 64 or data[:4] != b'\x7fELF' or data[4] != 2:
        raise ValueError('Expected a 64-bit ELF library')
    if data[5] not in (1, 2):
        raise ValueError('Unsupported ELF byte order')
    order = '<' if data[5] == 1 else '>'
    offset = struct.unpack_from(order + 'Q', data, 32)[0]
    entry_size, count = struct.unpack_from(order + 'HH', data, 54)
    if entry_size < 56 or not count or offset + entry_size * count > len(data):
        raise ValueError('Invalid ELF program headers')
    segments = []
    for index in range(count):
        start = offset + index * entry_size
        if struct.unpack_from(order + 'I', data, start)[0] != 1:
            continue
        file_offset, address = struct.unpack_from(order + 'QQ', data, start + 8)
        alignment = struct.unpack_from(order + 'Q', data, start + 48)[0]
        if alignment < PAGE_SIZE or alignment & (alignment - 1):
            raise ValueError(f'PT_LOAD alignment {alignment} is below or incompatible with 16 KB')
        if file_offset % PAGE_SIZE != address % PAGE_SIZE:
            raise ValueError('PT_LOAD offset and virtual address are not congruent at 16 KB')
        segments.append(alignment)
    if not segments:
        raise ValueError('ELF library has no loadable segments')
    return segments


def check_bundle(bundle):
    checked = []
    with zipfile.ZipFile(bundle) as archive:
        libraries = [n for n in archive.namelist() if n.endswith('.so') and
                     any('/lib/' + abi + '/' in n for abi in ('arm64-v8a', 'x86_64'))]
        if not any('/lib/arm64-v8a/' in n for n in libraries):
            raise ValueError('Bundle has no arm64-v8a libraries to validate')
        for name in sorted(libraries):
            try:
                segments = load_segments(archive.read(name))
            except ValueError as error:
                raise ValueError(f'{name}: {error}') from error
            checked.append({'library': name, 'loadSegmentAlignments': segments})
    return {'result': 'passed', 'minimumPageSize': PAGE_SIZE, 'checkedLibraries': checked,
            'scope': '64-bit ELF PT_LOAD alignment; final APK packaging and runtime testing remain separate'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('bundle')
    parser.add_argument('--report', default='build/release-checks/native-alignment.json')
    args = parser.parse_args()
    result = check_bundle(args.bundle)
    output = Path(args.report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(f"16 KB ELF alignment passed for {len(result['checkedLibraries'])} native libraries.")


if __name__ == '__main__':
    main()
