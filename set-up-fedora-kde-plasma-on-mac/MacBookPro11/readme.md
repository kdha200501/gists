# Install WiFi driver

The *Apple* Wifi chip needs proprietorial driver

*Fedora* updates occasionally breaks this driver, so be sure to change to manual update

- under "System Settings" -> "Software Update"



##### Add free and non free repositories

see ref: [link](https://rpmfusion.org/Configuration)

```shell
$ sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
$ sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```





##### Install driver

```shell
$ sudo dnf install broadcom-wl
$ sudo reboot
```





##### Workaround for driver incompatibility (`dcaratti/wpa_supplicant`)

```shell
$ sudo dnf upgrade --refresh --advisory=FEDORA=2024-8db3b7bb91
```





##### Workaround for the lack of scanning for WiFi network

Figure out network interface name:

```shell
$ ifconfig
```

Scan WiFi networks:

```shell
$ sudo iw dev <network interface name> scan
```





##### Side note

List WiFi networks:

```shell
$ nmcli dev wifi list
```

Join a WiFi network:

```shell
$ sudo nmcli --ask dev wifi connect <SSID>
```

Forget a WiFi network:

```shell
$ sudo nmcli con delete <SSID>
```

















# 