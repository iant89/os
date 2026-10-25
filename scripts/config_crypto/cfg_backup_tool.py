#!/usr/bin/env python3
"""cfg_backup_tool.py — analysis tool for Verizon VZSDK router configuration
backups (CR1000A/CR1000B; expected identical on WNC-CR200A — verify-live).

Research/inspection use: decrypt and inventory a config backup that you are
authorized to examine. This tool deliberately does NOT re-encrypt or repack
configs.

File format (recovered from community RE of the CR1000A firmware, OpenWrt
forum "Adding Support for Verizon CR1000A", spol-eff 2023-03-17; verified
against Configs/CR1000A_V3.1.0.21_backup.cfg):

  .cfg file = AES-256-CBC(plaintext_tar, key=K_cfg, iv=IV_file) || IV_file
      - IV_file  : 16 random bytes appended at END of file
      - plaintext: tar archive (community repack used tar.gz; device
        decompresses both per libmapi_backup.so RE)
  K_cfg (32 B) = AES-256-CBC-decrypt(K_wrap, iv=IV_hard, wrapped_key)
      - K_wrap   : 'egjyodltjhpdkgtkh234p6567la20flv' (32 ASCII bytes, i.e.
        0x65676a79... zero-padded to 64 B in firmware buffers)
      - IV_hard  : '6a70646c69667764' (16 ASCII bytes)
      - wrapped_key: 48-byte constant blob (.encrypt_data style)
  Integrity: tar member 'backup_md5' is expected but NOT actually verified
  by the firmware (empty-file md5 stub is accepted) — no MAC on the backup.

Usage:
  cfg_backup_tool.py info     <file.cfg>
  cfg_backup_tool.py decrypt  <file.cfg> [-o out.tar]
  cfg_backup_tool.py inspect  <file.cfg>     # member inventory, secrets redacted
"""

import argparse
import io
import re
import subprocess
import sys
import tarfile

K_WRAP_HEX = "65676a796f646c746a6870646b67746b6832333470363536376c613230666c76"
IV_HARD_HEX = "36613730363436633639363637373634"
WRAPPED_KEY_HEX = (
    "2e0ce09b5d412c36430bed8fb61af11b8834877351293fceedb55e812b9e8daa"
    "81e0c617117de5b87c93b505200c9b20"
)
IV_SIZE = 16

SECRET_RE = re.compile(
    r"(pass(?:word|phrase)?|wp[ak]|key|secret|psk|auth|token|serial|mac)[^=\n]{0,20}[=:]\s*\S+",
    re.IGNORECASE,
)


def aes(key: bytes, iv: bytes, payload: bytes, decrypt: bool = True) -> bytes:
    cmd = [
        "openssl", "enc", "-d" if decrypt else "-e", "-aes-256-cbc",
        "-K", key[:32].hex(), "-iv", iv.hex(),
    ]
    p = subprocess.run(cmd, input=payload, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"openssl failed: {p.stderr.decode(errors='replace')}")
    return p.stdout


def unwrap_key() -> bytes:
    return aes(bytes.fromhex(K_WRAP_HEX), bytes.fromhex(IV_HARD_HEX),
               bytes.fromhex(WRAPPED_KEY_HEX))


def read_container(path: str):
    data = open(path, "rb").read()
    if len(data) <= IV_SIZE or len(data) % 16 != 0:
        raise ValueError("not a VZSDK .cfg container (size not 16-aligned)")
    return data[:-IV_SIZE], data[-IV_SIZE:]


def cmd_info(path):
    payload, iv = read_container(path)
    k = unwrap_key()
    print(f"file          : {path}")
    print(f"total size    : {len(payload) + IV_SIZE} B")
    print(f"ciphertext    : {len(payload)} B (AES-256-CBC, 16-aligned)")
    print(f"trailing IV   : {iv.hex()}  ({IV_SIZE} B)")
    print(f"wrapped key   : 48 B constant blob")
    print(f"wrap key      : 32 ASCII bytes (constant, firmware buffer zero-padded)")
    print(f"wrap IV       : 16 ASCII bytes (constant)")
    print(f"unwrapped key : present ({len(k)} B)  [fingerprint sha256/8: "
          f"{__import__('hashlib').sha256(k).hexdigest()[:8]}]")
    print(f"integrity     : backup_md5 tar member, NOT verified by firmware")


def cmd_decrypt(path, out=None):
    payload, iv = read_container(path)
    plain = aes(unwrap_key(), iv, payload)
    out = out or (path.rsplit(".", 1)[0] + ".tar")
    open(out, "wb").write(plain)
    magic = plain[:4]
    kind = "gzip tar" if magic == b"\x1f\x8b\x08\x08" or magic[:2] == b"\x1f\x8b" else \
           "plain tar" if plain[257:262] == b"ustar" else f"unknown ({magic.hex()})"
    print(f"decrypted: {len(plain)} bytes ({kind}) -> {out}")


def cmd_inspect(path):
    payload, iv = read_container(path)
    plain = aes(unwrap_key(), iv, payload)
    tf = tarfile.open(fileobj=io.BytesIO(plain))
    print(f"{'member':<40} {'size':>8}  secrets")
    print("-" * 78)
    n_secret = 0
    for m in tf.getmembers():
        if not m.isfile():
            print(f"{m.name:<40} {'(dir)':>8}")
            continue
        data = tf.extractfile(m).read()
        hits = SECRET_RE.findall(data.decode(errors="replace")) if data else []
        flag = f"{len(hits)} potential secret(s)" if hits else ""
        if hits:
            n_secret += len(hits)
        print(f"{m.name:<40} {m.size:>8}  {flag}")
    print("-" * 78)
    print(f"members: {len(tf.getmembers())}, potential secrets: {n_secret} "
          "(values withheld — inspect privately on the lab VM)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("command", choices=["info", "decrypt", "inspect"])
    ap.add_argument("input")
    ap.add_argument("-o", "--output")
    args = ap.parse_args()
    try:
        {"info": lambda: cmd_info(args.input),
         "decrypt": lambda: cmd_decrypt(args.input, args.output),
         "inspect": lambda: cmd_inspect(args.input)}[args.command]()
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
