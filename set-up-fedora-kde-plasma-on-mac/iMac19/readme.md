# Install wifi firmware

The firmware for the (Broadcom) BCM4364 wifi chip is not included in the wifi driver. The firmware can be extracted when the iMac is running macOS Sonoma following the tarball method on the T2Linux guide (ref: [link](https://wiki.t2linux.org/guides/wifi-bluetooth)).

> [!IMPORTANT]
>
> The outcome of the extraction is attached to this guide: [firmware.tar](bcm4364-firmware-extraction/firmware.tar)





In Linux, 

```shell
sudo tar -v -xC /lib/firmware/brcm -f /path/to/firmware.tar

sudo modprobe -r brcmfmac_wcc
sudo modprobe -r brcmfmac
sudo modprobe brcmfmac
sudo modprobe -r hci_bcm4377
sudo modprobe hci_bcm4377
```

















# Install sound card driver

There are drivers for the CS8409 sound chip and none has made it to the Linux kernel. Compile and install the `snd_hda_macbookpro` driver.

> [!TIP]
>
> repeat for every kernel update

> [!WARNING]
>
> the `snd-hda-codec-cs8409` driver enables audio output, only *i.e.* it does not enable audio input, this is also observed by other users ref: [link](https://discussion.fedoraproject.org/t/no-sound-on-an-imac-27-5k-2017/71464/10)





##### Install dependencies for `snd_hda_macbookpro`

```shell
$ dnf install gcc kernel-devel make patch wget
```





##### Compile and install  `snd_hda_macbookpro`

ref: [link](https://github.com/davidjo/snd_hda_macbookpro?tab=readme-ov-file#compiling-and-installing-driver)

```shell
$ cd ~/Downloads
$ git clone https://github.com/davidjo/snd_hda_macbookpro.git
$ cd ~/Downloads/snd_hda_macbookpro
$ sudo ./install.cirrus.driver.sh
$ sudo reboot
```

