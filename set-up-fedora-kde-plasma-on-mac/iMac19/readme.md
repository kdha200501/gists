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

There are drivers for the CS8409 sound chip and none has made it to the Linux kernel.

> [!WARNING]
>
> the `snd-hda-codec-cs8409` driver enables audio output, only *i.e.* it does not enable audio input, this is also observed by other users ref: [link](https://discussion.fedoraproject.org/t/no-sound-on-an-imac-27-5k-2017/71464/10)





##### Compile and install `kdha200501/imac-cs8409-audio-driver`

The driver needs to be compiled and installed for every kernel update.

Instructions: [link](https://github.com/kdha200501/imac-cs8409-audio-driver)

> [!TIP]
>
> Download [checkout script](checkout.sh) and [agent skill](SKILL.md), use them to create new build source when the Linux kernel is updated through Fedora updates
>
> ```shell
> $ wget https://github.com/kdha200501/gists/raw/refs/heads/master/set-up-fedora-kde-plasma-on-mac/iMac19/SKILL.md
> $ wget https://github.com/kdha200501/gists/raw/refs/heads/master/set-up-fedora-kde-plasma-on-mac/iMac19/checkout.sh
> $ chmod +x checkout.sh
> 
> $ mkdir -p ~/.claude/skills/imac-driver-update
> $ mv SKILL.md checkout.sh ~/.claude/skills/imac-driver-update/
> 
> $ mkdir -p ~/.copilot/skills
> $ ln -s ~/.claude/skills/imac-driver-update ~/.copilot/skills/imac-driver-update
> 
> $ mkdir -p /path/to/edit/projects/directory
> $ cd /path/to/edit/projects/directory
> 
> # prompt a coding agent to, for example, "rebase iMac driver forks on top of Fedora"
> ```





##### Increase microphone input volume

> [!TIP]
>
> The firmware causes the microphone input volume to be extremely low. The workaround is to apply signal processing filters to obtain a usable mic input

```shell
$ sudo dnf install easyeffects
$ easyeffects
```

Under the "PipeWire" tab

- disable "Use Default Input"
- choose "Built-in Audio Analog Stereo"
- disable "Use Default Output"
- choose "Built-in Audio Analog Stereo"



Under the "Input" tab -> "Effects" sub-tab, repeat "Add Effect" for

> [!IMPORTANT]
>
> Use the grip to reorder these filters in the following order

- Auto gain
- Limiter
- Noise Reduction
- Gate



```shell
$ sudo reboot
```

