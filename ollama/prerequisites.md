# Ubuntu and kernel versions

##### kernel

```shell
$ uname -r
```

Example output:

```
6.8.0-85-generic
```

##### OS

```shell
$ lsb_release -a
```

Example output:

```
No LSB modules are available.
Distributor ID: Ubuntu
Description:    Ubuntu 24.04.3 LTS
Release:        24.04
Codename:       noble
```

> [!NOTE]
>
> `rocm` supports `6.8 [GA], 6.14 [HWE]` at `Ubuntu 24.04.3`





# Verify disk space

```shell
$ df -h
$ sudo vgdisplay
```

> [!WARNING]
>
> Ubuntu does not necessarily use all the available disk space



##### Claim unused disk space (if any)

```shell
$ sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
$ sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```





# Install `amdgpu` driver and the `rocm` backend

```shell
$ wget https://repo.radeon.com/amdgpu-install/7.0.2/ubuntu/noble/amdgpu-install_7.0.2.70002-1_all.deb
$ sudo apt install ./amdgpu-install_7.0.2.70002-1_all.deb
$ sudo apt update

$ sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
$ sudo apt install amdgpu-dkms

$ sudo apt install python3-setuptools python3-wheel
$ sudo usermod -a -G render,video $LOGNAME
$ sudo apt install rocm

$ sudo reboot
```

