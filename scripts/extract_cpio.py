#!/usr/bin/env python3
"""Extract a cpio 'newc' (SVR4, ASCII header) archive — pure stdlib.

Used to unpack initramfs root filesystems carved out of firmware images by
binwalk when the 'cpio' utility is unavailable.

Usage: extract_cpio.py <archive.cpio> <output-dir>
"""
import os
import struct
import sys


def extract(archive_path: str, outdir: str) -> int:
    os.makedirs(outdir, exist_ok=True)
    count = 0
    with open(archive_path, "rb") as f:
        while True:
            hdr = f.read(110)
            if len(hdr) < 110:
                break
            magic = hdr[:6]
            if magic not in (b"070701", b"070702"):
                raise ValueError(f"bad magic {magic!r} at offset {f.tell() - 110}")
            fields = [int(hdr[6 + 8 * i: 14 + 8 * i], 16) for i in range(13)]
            (ino, mode, uid, gid, nlink, mtime, filesize, devmaj, devmin,
             rdevmaj, rdevmin, namesize, check) = fields
            name = f.read(namesize)
            f.read(-(namesize + 110) % 4)  # header+name padding to 4 bytes
            name = name[:-1].decode("utf-8", "replace")  # strip trailing NUL
            if name == "TRAILER!!!":
                break
            data = f.read(filesize)
            f.read(-filesize % 4)  # data padding to 4 bytes
            target = os.path.join(outdir, name)
            if name.startswith("/") or ".." in name.split("/"):
                continue  # refuse to escape the output dir
            if (mode & 0o170000) == 0o040000:  # directory
                os.makedirs(target, exist_ok=True)
            elif (mode & 0o170000) == 0o120000:  # symlink
                os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
                try:
                    os.symlink(data.rstrip(b"\x00").decode("utf-8", "replace"), target)
                except FileExistsError:
                    pass
            elif (mode & 0o170000) == 0o100000:  # regular file
                os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
                with open(target, "wb") as out:
                    out.write(data)
                os.chmod(target, mode & 0o7777)
            # other types (fifo, device, socket) are skipped
            count += 1
    return count


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    n = extract(sys.argv[1], sys.argv[2])
    print(f"extracted {n} entries into {sys.argv[2]}")
