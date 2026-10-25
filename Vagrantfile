# Vagrantfile — firmware analysis VM (VirtualBox).
#
#   vagrant up          # creates the VM and provisions the full toolchain
#   vagrant reload      # after provisioning (applies dialout group membership)
#   vagrant ssh
#
# USB passthrough (UART adapter):
#   1. Install the VirtualBox Extension Pack on the HOST (USB 2.0/3.0 support).
#   2. Add your host user to the 'vboxusers' group, re-login.
#   3. The USB filters below attach CP2102/FT232 adapters automatically when
#      plugged in; or: VBoxManage list usbhost  /  Devices > USB menu in the GUI.
#   Inside the VM the adapter appears as /dev/firmware-uart (udev rule) or
#   /dev/ttyUSB0.

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "firmware-lab"
  config.vm.synced_folder ".", "/home/vagrant/os"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "firmware-lab"
    vb.memory = 8192
    vb.cpus = 4
    vb.gui = false

    # Silicon Labs CP2102/CP2102N
    vb.customize ["usbfilter", "add", "0", "--target", :id,
                  "--name", "cp210x", "--vendorid", "0x10c4", "--productid", "0xea60"]
    # FTDI FT232R/FT232RL
    vb.customize ["usbfilter", "add", "1", "--target", :id,
                  "--name", "ft232", "--vendorid", "0x0403", "--productid", "0x6001"]
    # FTDI FT2232D/H (UART+JTAG)
    vb.customize ["usbfilter", "add", "2", "--target", :id,
                  "--name", "ft2232", "--vendorid", "0x0403", "--productid", "0x6010"]
  end

  # Full online provision. For air-gapped use, first run
  #   scripts/build_firmware_lab_bundle.sh
  # copy firmware-lab-bundle/ next to this Vagrantfile, then pass: --bundle /vagrant/firmware-lab-bundle
  config.vm.provision "shell",
    path: "scripts/setup_firmware_lab.sh",
    args: ["--prefix", "/opt/firmware-lab"],
    privileged: true
end
