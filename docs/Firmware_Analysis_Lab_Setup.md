# Firmware Analysis Lab — Local, Offline Environment

A reproducible, **air-gap-capable** lab for WNC-CR200A firmware work: a Linux VM with
the full extraction/reverse-engineering toolchain (binwalk, unblob, firmware-mod-kit,
Ghidra, …) and a ready-to-wire **UART-over-USB** setup (CP2102 / FT232) for the
device's debug header. Everything is version-pinned in
`manifest/firmware-lab-tools.json` so the environment can be rebuilt identically and
installed **without internet**. Assembled 2026-10-25.

> The VM and the USB adapter live on *your* machine — this repo carries the
> automation (provisioners, udev rules, serial scripts) and the wiring/runbook.

## 1. What gets installed

| Tool | Version (pinned) | Purpose |
|---|---|---|
| binwalk | 2.3.3 (ReFirmLabs tag, tested) | signature scan + carving (`scripts/binwalk_extract_rootfs.sh`) |
| unblob | 26.6.4 | modern, maintained recursive extractor (primary workhorse) |
| jefferson | 0.4.8 | JFFS2 extraction |
| ubi-reader | 0.8.16 | UBI/UBIFS extraction |
| yaffshiv | git `a8f21283` | YAFFS2 extraction |
| sasquatch | git `b34aa5ef` (onekey-sec fork) | patched unsquashfs for vendor-modified squashfs |
| firmware-mod-kit | git `c72f45d7` | legacy unpack/repack (best-effort build; unblob supersedes it) |
| Ghidra | **12.2** (`ghidra_12.2_PUBLIC_20261016.zip`, JDK 21+) | disassembly/decompilation of u-boot, kernel, userspace |
| serial tools | picocom, minicom, tio, screen | UART console |
| system | squashfs-tools, mtd-utils, u-boot-tools, cpio, lzop, p7zip, hexedit… | image plumbing |

SHA-256 for every artifact is in the manifest (Ghidra's is the digest GitHub itself
publishes for the release asset). Pip tools are installed into an isolated venv at
`/opt/firmware-lab/venv` (no PEP-668 conflicts with distro Python).

## 2. The VM

Specs: x86_64, 4 vCPU, 8 GB RAM (Ghidra likes memory), 32 GB disk. Debian 12 or
Ubuntu 22.04/24.04. Two supported builders:

**VirtualBox + Vagrant** (simplest):
```bash
vagrant up        # creates ubuntu/jammy64 VM and runs scripts/setup_firmware_lab.sh
vagrant reload    # applies dialout group membership
vagrant ssh
```
The `Vagrantfile` also pre-installs **USB filters** for CP2102 (`10c4:ea60`) and
FT232 (`0403:6001`) adapters. Host prerequisites: VirtualBox **Extension Pack** (USB
2.0/3.0) and your host user in `vboxusers`.

**QEMU/KVM** (no VirtualBox; good for USB passthrough):
```bash
scripts/build_lab_vm_qemu.sh                # cloud image + cloud-init provisioning
scripts/build_lab_vm_qemu.sh --run          # start the existing VM
```
UART adapter passthrough example: `-device qemu-xhci -device usb-host,vendorid=0x10c4,productid=0xea60`.

A snapshot taken after provisioning is your **frozen offline environment** — revert
to it before each analysis session; nothing needs to phone home again.

## 3. Install without a hypervisor / offline

The same provisioner works on any Debian/Ubuntu box (including WSL2 with USB support
caveats — prefer a real VM for serial work):

```bash
# on the analysis machine (online):
sudo scripts/setup_firmware_lab.sh

# for an air-gapped machine — build the bundle once on an internet host:
scripts/build_firmware_lab_bundle.sh            # → firmware-lab-bundle-YYYYMMDD.tar.gz
#   …transfer the tarball…
tar xzf firmware-lab-bundle-*.tar.gz
sudo firmware-lab-bundle/setup_firmware_lab.sh --bundle firmware-lab-bundle

# verify any install:
scripts/setup_firmware_lab.sh --check
```
The bundle contains every pinned artifact plus the **full pip dependency closure**,
so the offline install never touches the network. `--skip-ghidra` drops the 570 MB
zip if you only want extraction tooling.

## 4. Ghidra quick start

```bash
/opt/ghidra/current/ghidraRun                      # GUI
ghidra-headless <projdir> <projname> -import <file>  # batch import/analyze
```
Useful first target — the U-Boot from the public CR1000A dump (32-bit ARM ELF,
contains the secure-boot image decryption path discussed in
`docs/WNC-CR200A_Boot_Process_and_Services.md`):
```bash
ghidra-headless ~/ghidra-projects cr1000a \
  -import downloads/cr1000a-dump/Firmware/uboot.elf
```

## 5. UART-to-USB adapter (CP2102 / FT232)

Goal: a serial console on the WNC-CR200A's debug header (**`JA1`**, unpopulated
2×3 — see `docs/WNC-CR200A_FCC_Internal_Photos_Analysis.md` for location and
photos) to watch U-Boot and the kernel, and to catch a bootloader prompt.

### 5.1 Adapter choice

| Adapter | Logic level | Notes |
|---|---|---|
| **CP2102N** (Silicon Labs `10c4:ea60`) | 3.3 V native | recommended; dead cheap; no level jumper to get wrong |
| **FT232RL/FT232R** (`0403:6001`) | set VCCIO jumper to **3.3 V** | genuine FTDI preferred (counterfeits brick under Windows driver updates) |
| **FT2232H/FT4232H** (`0403:6010/6011`) | 3.3 V, multi-channel | later JTAG+UART on one cable (ch A = JTAG, ch B = UART) |

### 5.2 Electrical safety — read before wiring

1. **Never connect the adapter's VCC/VBUS pin to the target.** Power the router from
   its own PSU; the adapter only shares GND/TX/RX.
2. **Measure before you connect.** Qualcomm IPQ-class SoC UART pins can be **1.8 V**
   or 3.3 V depending on the board design. With the router powered and the header
   idle, put a multimeter on each candidate pad vs GND: the console **TX** pad idles
   high at the I/O voltage (≈1.8 V or ≈3.3 V). If it is 1.8 V, use a level shifter
   (e.g. TXS0102) or a 1.8 V adapter — a 3.3 V FT232/CP2102 can damage the SoC.
3. **Common ground first.** GND is the pad with continuity to the metal shield/USB
   shell — identify it before anything else.
4. Expect 3 pads (GND, TX, RX) or 4 (+V sense) on the 2×3 header; unused pins may be
   a second function (JTAG) — leave them unconnected until identified.

### 5.3 Wiring

```
   WNC-CR200A JA1 (2x3)              CP2102 / FT232
   ┌───┬───┐
   │ ? │ ? │      GND  ─────────────── GND
   │ GND│TX │      TX   ─────────────── RX   (crossed!)
   │ ? │RX │      RX   ─────────────── TX   (crossed!)
   └───┴───┘      VCC  ──── (leave disconnected)
```
Pin order on the header is unknown until probed — the procedure: (1) find GND by
continuity; (2) power on with only GND connected and find the pad whose idle voltage
is the I/O rail (TX); (3) connect adapter RX to it and boot — if you see the U-Boot
banner you have found the console; (4) adapter TX goes to the remaining pad (RX).
The FCC photo analysis document has high-resolution board shots to locate `JA1`.

### 5.4 Host setup and connecting

```bash
sudo cp udev/99-firmware-lab-serial.rules /etc/udev/rules.d/ && sudo udevadm control --reload-rules
sudo usermod -aG dialout $USER          # re-login afterwards
ls -l /dev/firmware-uart /dev/ttyUSB*   # udev symlink appears when plugged in

scripts/uart_boot_capture.sh            # try 115200/57600/38400/9600/230400 while
                                        # you power-cycle — logs in logs/uart/
scripts/uart_connect.sh /dev/firmware-uart 115200
```
- Default console format is **115200 8N1** (U-Boot/IPQ807x convention); the capture
  script identifies the actual rate from the boot banner.
- Log everything: `uart_connect.sh` timestamps sessions into `logs/uart/`.
- On boot look for: U-Boot version banner (expect **2018.03**, per the GPL release),
  `Hit any key to stop autoboot`, kernel log, then the `procd: - early -` lines from
  the init sequence analyzed in `docs/WNC-CR200A_Boot_Process_and_Services.md`.

### 5.5 JTAG (later)

If `JA1` turns out to carry JTAG (or you attach to the SoC TCK/TMS/TDI/TDO pads),
use an FT2232H/FT232H with **OpenOCD** (`apt install openocd`) — the udev rules
already tag FTDI usb devices for access. Note that Qualcomm secure boot (the x509
chain in `uboot.elf`) can lock JTAG on production units.

## 6. Offline workflow recap

1. Build bundle on a connected host → transfer tarball.
2. `setup_firmware_lab.sh --bundle …` on the VM → `--check` → **snapshot**.
3. Bring firmware images in on removable media; carve with
   `scripts/binwalk_extract_rootfs.sh` / unblob; open artifacts in Ghidra from the
   local disk.
4. UART work happens on the VM's USB port (passthrough); no network needed.

## 7. Scope & care

The lab is for analysis of devices and firmware you are authorized to study (this
project: the owner's WNC-CR200A and publicly released material). Serial probing is
non-destructive when the voltage rules above are followed; opening the enclosure and
soldering headers may affect warranty — document photo evidence first
(`docs/WNC-CR200A_FCC_Internal_Photos_Analysis.md`).
