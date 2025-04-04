# Install Chrome

- Download and install the `.rpm` version of Google Chrome, ref: [link](https://www.google.com/chrome/)

- Enable two finger pinch zoom
  - go to "chrome://flags/#ozone-platform-hint"
  - select "Wayland"

















# Install *Typora*

*Typroa* is hands down the best *Markdown* editor

- it is not free
- the easiest way to install is through a unofficial script (ref: [link](https://github.com/RPM-Outpost/typora)):

```shell
$ cd ~/Downloads
$ git clone https://github.com/RPM-Outpost/typora.git
$ cd typora
$ ./create-package.sh
$ sudo ln -s /opt/typora/Typora /usr/bin/typora
```

















# Install `vim`

`vi` does not support syntax highlighting, so....

```shell
$ sudo dnf install vim
$ touch ~/.vimrc
$ vim ~/.vimrc
```

Add the following:

```
set whichwrap+=<,>,h,l,[,]
syntax on
```

















# Install *Atom*

*Atom* is the most hack-able text editor

- it's no longer under development



##### Install `nvm`

```shell
$ curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
$ source ~/.bashrc

$ nvm -v
```





##### Install *Node.js* and its package manager

```shell
$ nvm install 18.20

$ node -v
$ npm -v
```





##### Install *Atom*

Download `atom.x86_64.rpm` from *GitHub* (ref: [link](https://github.com/atom/atom/releases/tag/v1.60.0)) and install





##### Install *Atom* plug-ins

- `prettier-atom` ref: [link](https://github.com/prettier/prettier-atom/tags)
- `atom-runner` ref: [link](https://github.com/lsegal/atom-runner/tags)

```shell
$ mkdir ~/.atom/packages

$ cd ~/.atom/packages
$ git clone https://github.com/lsegal/atom-runner.git
$ cd atom-runner
$ npm i

$ cd ~/.atom/packages
$ git clone https://github.com/prettier/prettier-atom.git
$ cd prettier-atom
$ npm i
$ npm audit fix --force
```

















# Use F1 to F12 as function keys

The *Apple* keyboard has a `fn` key that acts like a `shift` key for the function keys so that, function key behave as either a function key or a OS feature.

Developers need function keys to behave as function keys by default (*i.e.* without holding the `fn` key)



```shell
$ sudo vim /etc/modprobe.d/hid_apple.conf
```

Add the following:

```
options hid_apple fnmode=2
```





```shell
$ sudo vim /etc/dracut.conf.d/hid_apple.conf
```

Add the following:

```
install_items+=/etc/modprobe.d/hid_apple.conf
```





Apply changes:

```shell
$ sudo dracut --force
$ sudo reboot
```

















# Install WiFi driver

The *Apple* Wifi chip needs proprietorial driver

*Fedora* updates occasionally breaks this driver, so be sure to change to manual update

- under "System Settings" -> "Software Update"



##### Add free and non free repositories

- see ref: [link](https://rpmfusion.org/Configuration)





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

















# Fix wake from sleep issue

Fedora running on MacBook takes minutes to wake from sleep and some users managed to find log entries that suggest it is the side effect of an unknown CPU core lockup issue (ref: [link](https://discussion.fedoraproject.org/t/disabling-cpu-before-suspend-and-enabling-it-after-wake-up/81890/19))

> May 09 23:46:44 fedora kernel: watchdog: BUG: soft lockup - CPU#5 stuck for 22s! [cpuhp/5:40]



The workaround is to disable some CPU cores right before the MacBook goes into sleep and re-enable the CPU cores right after sleep ends (ref: [link](https://gist.github.com/jakob-hede/66e9f3439d0891f090fe99daef45cf0d)).



##### Create a program to toggle CPU cores' online state using shell script 

```shell
$ sudo mkdir /opt/toggle-core
$ sudo touch /opt/toggle-core/toggle-core.sh
$ sudo chmod +x /opt/toggle-core/toggle-core.sh
$ sudo ln -s /opt/toggle-core/toggle-core.sh /usr/bin/toggle-core
$ sudo vim /opt/toggle-core/toggle-core.sh
```

Add the following:

```shell
#!/bin/bash

validateBoolean() {
  if [[ "$1" =~ ^[01]$ ]]; then
    return 0
  fi

  return 1
}

validateInteger() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  return 1
}

args=("$@")
declare status mask argIndex=-1

for ((i = 0; i < $#; i++)); do
  if [ "${args[$i]}" == "--help" ]; then
    echo -e "toggle-core [OPTIONS...]\n"
    echo -e "Toggle selected CPU cores on or off.\n"
    echo -e "  --help              Show this help\n"
    echo -e "  -s [boolean]        The status selected CPU cores are to be set to i.e. \"1\" or \"0\"\n"
    echo -e "  -m [integer]        The selection of CPU cores in bit mask e.g. \"1\" refers to CPU core <0>; \"3\" refers to CPU cores <0, 1>\n"
    exit 0
  fi

  if [ $argIndex -eq $i ]; then
    continue
  fi

  if [ "${args[$i]}" == "-s" ]; then
    argIndex=$((i+1))
    validateBoolean "${args[$argIndex]}"

    if [ $? -eq 0 ]; then
      status="${args[$argIndex]}"
    else
      i=$#
    fi

    continue
  fi

  if [ "${args[$i]}" == "-m" ]; then
    argIndex=$((i+1))
    validateInteger "${args[$argIndex]}"

    if [ $? -eq 0 ]; then
      mask="${args[$argIndex]}"
    else
      i=$#
    fi

    continue
  fi
done


# if the status option is absent
if [[ ! -v status ]]; then
  # then exit with error
  logger -t "toggle-core" -p user.error "Error: missing status option"
  exit 1
fi

# if the mask option is absent
if [[ ! -v mask ]]; then
  # then exit with error
  logger -t "toggle-core" -p user.error "Error: missing mask option"
  exit 1
fi

declare maskSize=0 cupCoreSelections=()

while [ $mask -gt 0 ]; do
  if (( mask & 1 )); then
    cupCoreSelections+=($maskSize)
  fi
  mask=$((mask >> 1))
  ((maskSize++))
done

# if the bit mask contains no CPU core selection
if [ $maskSize -eq 0 ]; then
  # then exit with error
  logger -t "toggle-core" -p user.error "Error: no CPU core selection is specified"
  exit 1
fi

cupCoreNum=$(nproc --all)

# if the bit mask may contain more CPU core selections than there are actual CPU cores
if [ $maskSize -gt $cupCoreNum ]; then
  # then exit with error
  logger -t "toggle-core" -p user.error "Error: oversized mask {size: $maskSize}"
  exit 1
fi

# if the first CPU core is to be toggled
if [ ${cupCoreSelections[0]} -eq 0 ]; then
  # then exit with error
  logger -t "toggle-core" -p user.error "Error: cannot toggle the first CPU core"
  exit 1
fi


logger -t "toggle-core" -p user.info "setting CPU cores < ${cupCoreSelections[*]} > to \"$status\""

for cupCoreSelection in "${cupCoreSelections[@]}"; do
  echo "$status" > "/sys/devices/system/cpu/cpu${cupCoreSelection}/online"
done

```



##### Toggle CPU cores' online state during sleep events

```shell
$ sudo mkdir /opt/fix-long-wake-from-sleep
$ sudo touch /opt/fix-long-wake-from-sleep/fix-long-wake-from-sleep.service
$ sudo vim /opt/fix-long-wake-from-sleep/fix-long-wake-from-sleep.service
```

Add the following:

```shell
[Unit]
Description=Toggle CPU cores' online state during sleep events
PartOf=sleep.target

[Service]
Type=simple
RemainAfterExit=yes
ExecStart=/bin/bash -c 'toggle-core -s 0 -m 254'
ExecStop=/bin/bash -c 'toggle-core -s 1 -m 254'

[Install]
WantedBy=sleep.target

```

Install the service:

```shell
$ systemctl enable /opt/fix-long-wake-from-sleep/fix-long-wake-from-sleep.service
$ systemctl status fix-long-wake-from-sleep.service
```

Logs can be found using:

```shell
$ journalctl -t "toggle-core"
```

















# Install Facetime HD driver

##### Download and extract firmware

```shell
$ cd ~/Downloads
$ git clone https://github.com/patjak/facetimehd-firmware.git
$ cd ~/Downloads/facetimehd-firmware
$ make
```



##### Install firmware

ref: [link](https://github.com/patjak/facetimehd/wiki/Get-Started#firmware-extraction)

```shell
$ sudo make install

$ sudo touch /etc/dracut.conf.d/facetimehd.conf
$ sudo vim /etc/dracut.conf.d/facetimehd.conf
```

Add the following:

```shell
install_items+=" /usr/lib/firmware/facetimehd/firmware.bin "
```





##### Download and extract colour profiles

Get Bootcamp driver from Apple, links: [ref 1](https://github.com/patjak/facetimehd/wiki/Extracting-the-sensor-calibration-files) [ref 2](https://support.apple.com/kb/DL1837)

```shell
$ mkdir -p ~/Downloads/facetimehd-color-profile
$ cd ~/Downloads/facetimehd-color-profile
$ mv ../bootcamp5.1.5769.zip ./
$ unzip bootcamp5.1.5769.zip
$ cd /BootCamp/Drivers/Apple
$ unrar x AppleCamera64.exe

$ dd bs=1 skip=1663920 count=33060 if=AppleCamera.sys of=9112_01XX.dat
$ dd bs=1 skip=1644880 count=19040 if=AppleCamera.sys of=1771_01XX.dat
$ dd bs=1 skip=1606800 count=19040 if=AppleCamera.sys of=1871_01XX.dat
$ dd bs=1 skip=1625840 count=19040 if=AppleCamera.sys of=1874_01XX.dat

$ md5sum *.dat
```

Verify checksums:

```
a1831db76ebd83e45a016f8c94039406  1771_01XX.dat
017996a51c95c6e11bc62683ad1f356b  1871_01XX.dat
3c3cdc590e628fe3d472472ca4d74357  1874_01XX.dat
479ae9b2b7ab018d63843d777a3886d1  9112_01XX.dat
```



##### Add colour profiles to the firmware

```shell
$ sudo cp *.dat /usr/lib/firmware/facetimehd/
$ sudo reboot
```



##### Add non free repository

ref: [link](https://copr.fedorainfracloud.org/coprs/frgt10/facetimehd-dkms/)

```shell
$ sudo dnf copr enable frgt10/facetimehd-dkms
```



##### Install driver

```shell
$ sudo dnf install facetimehd
```

















# Install utility to identify key names [optional]

These utilities are useful for learning how to remap keys



##### Approach 1: Use `wev`

This is the `wayland` version of `ev`

```shell
$ sudo dnf copr enable wef/wev -y
$ sudo dnf install wev

$ wev
```





##### Approach 2: Learn from the source code of `evdev`

ref: [link](https://github.com/emberian/evdev/blob/main/src/scancodes.rs)

also see: `/usr/include/linux/input-event-codes.h`

















# Grant the current user access to `/dev/input/`

Both `xremap` and `ydotoold` need this permission

- we need `xremap` for remapping keyboard shortcuts
- we need `fusuma` for remapping gestures to actions
  - `fusuma` needs  `ydotool` for converting gesture to keyboard shortcuts
    - `ydotool` needs `ydotoold` for sending keyboard shortcuts





##### Add the current user to the `input` group

```shell
$ sudo gpasswd -a $USER input
$ newgrp input

$ groups
```





##### Give the `input` group the permissions to read and write to `/dev/input/`

Note, this will allow the current user to run  `xremap` without root permission

```shell
$ echo 'KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/input.rules
$ sudo reboot

$ ls -la /dev/uinput
```

















# Remap keyboard shortcuts

While some *Linux* shortcuts are easy to learn, most are not. The more effective way is to port *macOS* shortcuts to *Linux*.



##### Install `rust` and its package manager

```shell
$ sudo dnf install rust cargo
$ atom ~/.bash_profile
```

Add the following:

```
export PATH=$PATH:~/.cargo/bin/
```

```shell
$ source  ~/.bash_profile
```





##### Install `xremap`

```shell
$ cargo install xremap --features kde
```

note: installs to the current user





##### Configure `xremap`

```shell
$ mkdir ~/.xremap
$ touch ~/.xremap/config.json
$ atom ~/.xremap/config.json
```

Add the following:

```json
{
  "modmap": [
    {
      "name": "Convert the meta keys to the control keys",
      "remap": {
        "Super_L": "Control_L",
        "Super_R": "Control_R",
        "Control_L": "Super_L",
        "Control_R": "Super_R"
      }
    }
  ],
  "keymap": [
    {
      "name": "Text navigation",
      "remap": {
        "Control-Left": "Home",
        "Control-Right": "End",
        "Alt-Left": "Control-Left",
        "Alt-Right": "Control-Right"
      }
    },
    {
      "name": "Windows, tabs and history",
      "remap": {
        "Control-Q": "Alt-F4",
        "Control-Shift-KEY_RIGHTBRACE": "Control-KEY_PAGEDOWN",
        "Control-Shift-KEY_LEFTBRACE": "Control-KEY_PAGEUP",
        "Control-KEY_RIGHTBRACE": "Alt-Right",
        "Control-KEY_LEFTBRACE": "Alt-Left",
        "Control-M": "Super-KEY_PAGEDOWN",
        "Super-Right": "Super-Control-Right",
        "Super-LEFT": "Super-Control-Left",
        "Super-Up": "Super-Control-Up",
        "Super-Down": "Super-Control-Down",
        "F11": "Control-F12",
        "F3": "Control-F9"
      }
    },
    {
      "name": "Windows, tabs and history [continues...]",
      "application": {
        "not": ["plasmashell"]
      },
      "remap": {
        "Control-H": "Super-KEY_PAGEDOWN"
      }
    },
    {
      "name": "Runner",
      "remap": {
        "Control-Space": "Alt-Space"
      }
    },
    {
      "name": "Screenshot",
      "remap": {
        "Control-Shift-4": "Super-Shift-KEY_PRINT"
      }
    },
    {
      "name": "Unwanted shortcuts",
      "remap": {
        "Super-L": "Control-L"
      }
    },
    {
      "name": "File manager",
      "application": {
        "only": "dolphin"
      },
      "remap": {
        "Control-Shift-H": "Alt-Home",
        "Control-Up": "Alt-Up",
        "Control-BackSpace": "Delete",
        "Control-I": "Alt-KEY_ENTER",
        "Control-KEY_COMMA": "Control-Shift-KEY_COMMA",
        "Alt-Up": "HOME",
        "Alt-Down": "End"
      }
    },
    {
      "name": "File dialog",
      "application": {
        "only": "org.freedesktop.impl.portal.desktop.kde"
      },
      "remap": {
        "Control-Shift-H": "Alt-Home",
        "Control-Up": "Alt-Up",
        "Control-Down": "Enter",
        "Alt-Up": "HOME",
        "Alt-Down": "End",
        "F2": "Enter"
      }
    },
    {
      "name": "Terminal",
      "application": {
        "only": "konsole"
      },
      "remap": {
        "Super-C": "Control_L-C",
        "Super-A": "Control_L-A",
        "Super-E": "Control_L-E",
        "Super-Z": "Control_L-Z",
        "Control-C": "Control_L-Shift-C",
        "Control-V": "Control_L-Shift-V",
        "Control-T": "Control_L-Shift_L-T",
        "Control-N": "Control_L-Shift_L-N",
        "Control-W": "Control_L-Shift_L-W",
        "Control-Q": "Alt_L-F4",
        "Control-Shift-KEY_LEFTBRACE": "Shift_L-Left",
        "Control-Shift-KEY_RIGHTBRACE": "Shift_L-Right"
      }
    },
    {
      "name": "Atom",
      "application": {
        "only": "Atom"
      },
      "remap": {
        "Control-Shift-P": "Control-Alt-F",
        "Control-Shift-R": "Alt-R",
        "Control-G": "F3",
        "Alt-Shift-Up": "Control-Up",
        "Alt-Shift-Down": "Control-Down",
        "Control-D": "Control-Shift-D",
        "Control-Shift-N": "Control-P",
        "Control-N": "Control-Shift-N",
        "Control-T": "Control-N",
        "Control-9": "Control-Shift-9",
        "Control-1": ["Control-K", "Control-B"],
        "Control-L": "Control-G"
      }
    },
    {
      "name": "Typora",
      "application": {
        "only": "Typora"
      },
      "remap": {
        "Control-G": "F3"
      }
    }
  ]
}
```





##### Test out `xremap` [optional]

The print out at runtime is especially useful determining what applications are called *i.e.* the "class" property is the application name

```shell
$ xremap ~/.xremap/config.json
```





##### Run `xremap` upon user log in

```shell
$ touch ~/.xremap/launch.sh
$ chmod u+x ~/.xremap/launch.sh
$ atom ~/.xremap/launch.sh
```

Add the following:

```sh
#!/bin/bash
~/.cargo/bin/xremap --watch ~/.xremap/config.json > /dev/null 2>&1
```

> the `--watch` option tells xremap to watch for newly added keyboards and apply the same remapping

Launch "System Settings"

Go to "Autostart" -> "Add" -> "Add Login Script"

Choose `launch.sh`

```shell
$ sudo reboot
```





##### Turn on number lock upon user log in

Launch "System Settings"

Go to "Keyboard" -> "Keyboard"

- set "NumLock on startup" to "Turn on"





##### Remap shortcut for task switcher

Launch "System Settings"

Go to "Window Management" -> "Task Switcher"

- set "Forward" to `⌘` + `Tab`
  - it will be recognized as `Ctrl` + `Tab`
- set "Reverse" to `⌘` + `Shift` + `Tab`
  - it will be recognized as `Ctrl` + `Shift` + `Tab`

















# Remap gestures to keyboard shortcuts

##### Setup development for `kwin`

```shell
$ cd ~/Downloads
$ git clone https://invent.kde.org/plasma/kwin.git

# branch off of the correct version
$ cd kwin
$ git fetch --prune
$ kwin_wayland --version
$ git checkout v6.1.6
$ git checkout -b jacks-customizations

# install dependencies
$ sudo dnf groupinstall "Development Tools"
$ sudo dnf builddep kwin
$ mkdir build
$ cd build
$ cmake ..
```





##### Disable three finger gestures

so that `fusuma` can be configured to react to three-finger gestures

```diff
From 9819388aea6191360cb6e932786d8a190c5c0e8c Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Tue, 24 Sep 2024 17:25:01 -0400
Subject: [PATCH] jacks-customizations: disable three finger gestures

---
 src/virtualdesktops.cpp | 32 ++++++++++++++++----------------
 1 file changed, 16 insertions(+), 16 deletions(-)

diff --git a/src/virtualdesktops.cpp b/src/virtualdesktops.cpp
index a0a09040d4..c221c652d2 100644
--- a/src/virtualdesktops.cpp
+++ b/src/virtualdesktops.cpp
@@ -769,24 +769,24 @@ void VirtualDesktopManager::initShortcuts()
             Q_EMIT currentChanging(currentDesktop(), m_currentDesktopOffset);
         }
     };
-    input()->registerTouchpadSwipeShortcut(SwipeDirection::Left, 3, m_swipeGestureReleasedX.get(), left);
-    input()->registerTouchpadSwipeShortcut(SwipeDirection::Right, 3, m_swipeGestureReleasedX.get(), right);
+    // input()->registerTouchpadSwipeShortcut(SwipeDirection::Left, 3, m_swipeGestureReleasedX.get(), left);
+    // input()->registerTouchpadSwipeShortcut(SwipeDirection::Right, 3, m_swipeGestureReleasedX.get(), right);
     input()->registerTouchpadSwipeShortcut(SwipeDirection::Left, 4, m_swipeGestureReleasedX.get(), left);
     input()->registerTouchpadSwipeShortcut(SwipeDirection::Right, 4, m_swipeGestureReleasedX.get(), right);
-    input()->registerTouchpadSwipeShortcut(SwipeDirection::Down, 3, m_swipeGestureReleasedY.get(), [this](qreal cb) {
-        if (grid().height() > 1) {
-            m_currentDesktopOffset.setY(-cb);
-            Q_EMIT currentChanging(currentDesktop(), m_currentDesktopOffset);
-        }
-    });
-    input()->registerTouchpadSwipeShortcut(SwipeDirection::Up, 3, m_swipeGestureReleasedY.get(), [this](qreal cb) {
-        if (grid().height() > 1) {
-            m_currentDesktopOffset.setY(cb);
-            Q_EMIT currentChanging(currentDesktop(), m_currentDesktopOffset);
-        }
-    });
-    input()->registerTouchscreenSwipeShortcut(SwipeDirection::Left, 3, m_swipeGestureReleasedX.get(), left);
-    input()->registerTouchscreenSwipeShortcut(SwipeDirection::Right, 3, m_swipeGestureReleasedX.get(), right);
+    // input()->registerTouchpadSwipeShortcut(SwipeDirection::Down, 3, m_swipeGestureReleasedY.get(), [this](qreal cb) {
+    //     if (grid().height() > 1) {
+    //         m_currentDesktopOffset.setY(-cb);
+    //         Q_EMIT currentChanging(currentDesktop(), m_currentDesktopOffset);
+    //     }
+    // });
+    // input()->registerTouchpadSwipeShortcut(SwipeDirection::Up, 3, m_swipeGestureReleasedY.get(), [this](qreal cb) {
+    //     if (grid().height() > 1) {
+    //         m_currentDesktopOffset.setY(cb);
+    //         Q_EMIT currentChanging(currentDesktop(), m_currentDesktopOffset);
+    //     }
+    // });
+    // input()->registerTouchscreenSwipeShortcut(SwipeDirection::Left, 3, m_swipeGestureReleasedX.get(), left);
+    // input()->registerTouchscreenSwipeShortcut(SwipeDirection::Right, 3, m_swipeGestureReleasedX.get(), right);
 
     // axis events
     input()->registerAxisShortcut(Qt::MetaModifier | Qt::AltModifier, PointerAxisDown,
-- 
2.47.0
```





##### Disable natural swiping

"Natural" is unatural to me, so...

```diff
From 07ae3f524bdabc995fb10eb8c0a4539db30e7acf Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Tue, 24 Sep 2024 17:25:50 -0400
Subject: [PATCH] jacks-customizations: disable natural swiping

---
 src/virtualdesktops.cpp | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)

diff --git a/src/virtualdesktops.cpp b/src/virtualdesktops.cpp
index c221c652d2..9aa7ca16de 100644
--- a/src/virtualdesktops.cpp
+++ b/src/virtualdesktops.cpp
@@ -771,8 +771,8 @@ void VirtualDesktopManager::initShortcuts()
     };
     // input()->registerTouchpadSwipeShortcut(SwipeDirection::Left, 3, m_swipeGestureReleasedX.get(), left);
     // input()->registerTouchpadSwipeShortcut(SwipeDirection::Right, 3, m_swipeGestureReleasedX.get(), right);
-    input()->registerTouchpadSwipeShortcut(SwipeDirection::Left, 4, m_swipeGestureReleasedX.get(), left);
-    input()->registerTouchpadSwipeShortcut(SwipeDirection::Right, 4, m_swipeGestureReleasedX.get(), right);
+    input()->registerTouchpadSwipeShortcut(SwipeDirection::Left, 4, m_swipeGestureReleasedX.get(), right);
+    input()->registerTouchpadSwipeShortcut(SwipeDirection::Right, 4, m_swipeGestureReleasedX.get(), left);
     // input()->registerTouchpadSwipeShortcut(SwipeDirection::Down, 3, m_swipeGestureReleasedY.get(), [this](qreal cb) {
     //     if (grid().height() > 1) {
     //         m_currentDesktopOffset.setY(-cb);
-- 
2.47.0
```





##### Compile and install `kwin`

```shell
$ make -j 8
$ sudo make install
$ kwin_wayland --replace &
```





##### Install `ydotool`

```shell
$ sudo dnf copr enable wef/ydotool 
$ sudo dnf install ydotool
```

ref: [link](https://copr.fedorainfracloud.org/coprs/wef/ydotool/)





##### Install `ruby` and its package manager

```shell
$ sudo dnf install ruby
```





##### Install `fusuma`

```shell
$ sudo gem install fusuma
```

note: installs globally





##### Configure `fusuma`

```shell
$ mkdir ~/.fusuma
$ touch ~/.fusuma/config.yml
$ atom ~/.fusuma/config.yml	
```

Add the following:

```yaml
swipe:
  3:
    left:
      command: 'ydotool key 56:1 105:1 105:0 56:0'
      threshold: 0.5
    right:
      command: 'ydotool key 56:1 106:1 106:0 56:0'
      threshold: 0.5
```





##### Test `fusuma` [optional]

```shell
$ ydotoold
$ fusuma -c ~/.fusuma/config.yml
```





##### Disable the installed daemon

The `ydotool.service` does not work, so...

```shell
$ sudo systemctl stop ydotool.service
$ sudo systemctl disable ydotool.service
```





##### Run `fusuma` upon user log in

```shell
$ touch ~/.fusuma/launch.sh
$ chmod u+x ~/.fusuma/launch.sh
$ atom ~/.fusuma/launch.sh
```

Add the following:

```sh
#!/bin/bash
fusuma -d -c ~/.fusuma/config.yml > /dev/null 2>&1
```

Launch "System Settings"

Go to "Autostart" -> "Add" -> "Add Application" -> Browse -> `/usr/bin/ydotoold`

Go to "Autostart" -> "Add" -> "Add Login Script"

Choose `launch.sh`

```shell
$ sudo reboot
```

















# Disable gestures

When two finger tap is configured to trigger right click, three finger tap is forcefully configured to trigger middle click. The middle click invokes paste. The three finger tap can only be disabled through recompiling `libinput`



##### Setup development for `libinput`

```shell
$ cd ~/Downloads
$ git clone https://gitlab.freedesktop.org/libinput/libinput.git

# branch off of the correct version
$ cd libinput
$ git fetch --prune
$ libinput --version
$ git checkout 1.26.2
$ git checkout -b jacks-customizations

# install dependencies
$ mkdir build
$ sudo dnf install meson ninja-build
$ sudo dnf install mtdev-devel.x86_64 libevdev-devel.x86_64 libwacom-devel.x86_64 check-devel.x86_64
$ meson setup --prefix=/usr build/
```



##### Disable three finger tap

```diff
From 62c1cafd9a714a47c1040d5740054a54ce79b8d7 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Sun, 20 Oct 2024 14:45:58 -0400
Subject: [PATCH] jacks-customizations: disable three finger tap

---
 src/evdev-mt-touchpad-tap.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/src/evdev-mt-touchpad-tap.c b/src/evdev-mt-touchpad-tap.c
index 299cd554..b7de2f5b 100644
--- a/src/evdev-mt-touchpad-tap.c
+++ b/src/evdev-mt-touchpad-tap.c
@@ -133,7 +133,7 @@ tp_tap_notify(struct tp_dispatch *tp,
 
 	assert(tp->tap.map < ARRAY_LENGTH(button_map));
 
-	if (nfingers < 1 || nfingers > 3)
+	if (nfingers < 1 || nfingers > 2)
 		return;
 
 	button = button_map[tp->tap.map][nfingers - 1];
-- 
2.47.0
```





##### Compile and install `libinput`

```shell
$ ninja -C build/ -j 8
$ sudo ninja -C build/ install
$ sudo reboot
```

















# Disable desktop session restore

Launch "System Settings"

Go to "Desktop Session"

Select "Start with an empty session"

















# Disable childish bouncing animation

Launch "System Settings"

Go to "Colors & Themes" -> "Cursors" -> "Configure Launch Feedback"

Set "Cursor feedback" to `None`

















# Customize panel

Right click on desktop -> "Enter Edit Mode" -> click on the panel

- move panel to top
- use full width
- height: 26 (this makes the optimal padding around the icons, see later)
- disable floating
- opacity is broken, so
  - install "Maia Transparent" from "System Settings" -> "Plasma Style" -> "Get New"
  - Enable "Blur" and disable "Background Contrast" under "System Settings" -> "Desktop Effects"
- disable top-left corner *CTA* under "System Settings" -> "Screen Edges" -> The top left *CTA* -> "No action"
- display the current application's icon on top-left corner
  - right click on panel -> "Show Panel Configuration" -> "Add Widgets" -> "Get New Widgets" -> "Download New Plasma Widgets"
    - search for "Window Title Applet 6 by dhruv8sh"


















# Customize window behaviors

Under "System Settings" -> "Window Management" -> "Desktop Effects" -> "Window Open/Close Animation"

- select "Fade"

Under "System Settings" -> "Workspace" -> "General Behavior" 

- disable "Display informational tooltips on mouse over"



##### In *Dolphin*

- right click on empty space the left column -> "Icon Size" -> "Large"
- go to settings (`⌘` + `,`) -> "View" -> "General"
  - set "Double-click triggers" to "Nothing"
  - enable "Open folders during drag operations"
  - disable "Show selection marker"
- go to settings (`⌘` + `,`) -> "Interface" -> "Folders & Tabs" -> "Show on startup"
  - set to home directory
- go to settings (`⌘` + `,`) -> "Interface" -> "Status & Location bars"
  - disable "Show zoom slider"
  - enable "Show full path inside location bar"
- go to the app menu -> "View"
    - disable "Show previews"



##### In *Krunner*

- go to configurations

  - to set position to "Center"

  - to disable "Activate when pressing any key on the desktop"


- there's no font settings
  - to change font:


```shell
$ atom ~/.config/krunnerrc
```

Add the following under `[General]`

```
font=Noto Sans,18,-1,5,50,0,0,0,0,0
```

```shell
$ sudo reboot
```



















# Customize wallpapers

##### The background image for the wake up screen

- under "System Settings" -> "Security & Privacy" -> "Screen Locking" -> "Configure Appearance"

  - customize user profile picture

    ```shell
    $ inkscape -w 128 -h 128 "/path/to/file.svg" -o "/path/to/file.svg.png"
    ```

    then select the .png file under "System Settings" -> "Users"




##### The background image for the desktop

- under "System Settings" -> "Wallpaper"



##### The background image for the lock screen

- under "System Settings" -> "Colors & Themes" -> "Login Screen (SDDM)" -> "Change Background Image"
  - system wall papers are located at `/usr/share/wallpapers/`
  
  - customize user profile picture
  
    ```shell
    $ sudo cp "/path/to/file.svg" "/usr/share/sddm/faces/.$USER.face.icon"
    ```
  
    


















# Customize icons

##### Add missing MIME type mapping

Go to "System Settings" -> "File Associations" -> "Add"

- Choose "text" for Group", type "typescript" for "Type name"





##### Install system icons

For example, switching to some Mac OS 9 icons:

```shell
$ cd ~/.local/share/icons/
$ git clone git@github.com:kdha200501/jacks-kde-icon-pack.git
```

*n.b.* credit goes to marcello-c ref: [link 1](https://www.deviantart.com/marcello-c/art/Classic-Mac-Style-Drives-for-OS-X-625109975) [link2](https://www.deviantart.com/marcello-c/art/Classic-Mac-Style-Folders-for-OS-X-624900831)





##### Install cursor icons

Under "System Settings" -> "Colors & Themes" -> "Cursor" -> "Get New"

For example, switching to Mac OS cursor icons:

- search for "Mac OS by dcppdp"

















# Customize window decoration

Window decoration refers to the window frame

- including the styling for window title bar and its buttons
- not including the styling for window boarders
- not including the styling for window scrollbar
- not including the styling for applications' UI elements



*Aurorae* based (*i.e.* not *Breeze*) window decorations can be downloaded and installed from the KDE store

- Instead of drawing UI components programatically, an *Aurorae* customization draws UI components by injecting .svg files, giving the customization a richer look and feel
- *Aurorae* customizations are stored under `~/.local/share/aurorae/themes/`





##### Install a window decoration

For example, installing a BeOS decoration

- Under "System Settings" -> "Colors & Themes" - > "Window Decorations" -> "Get New"
  - and then apply "Besot Haiku"

















# Convert the installed decoration into Mac OS 9

Using assets generously provided by Michael Feeney (ref: [link](https://www.figma.com/community/file/966779730364082883/mac-os-9-ui-kit)), we apply the Mac OS 9 platinum design on top of the BeOS decoration

```shell
$ cd ~/.local/share/aurorae/themes
$ git clone git@github.com:kdha200501/jacks-kde-window-decoration.git
$ mv jacks-kde-window-decoration besothaiku
```

Customize title bar buttons

- Under "System Settings" -> "Colors & Themes" -> "Window Decorations" -> "Configure Titlebar Buttons"
  - remove unwanted buttons from title bar and rearrange button positions






##### Customize window decoration

Some customizations cannot be made through using .svg files or updating the rc file such as adding background to the window title text.

*Aurorae* is written in QML, and its code base is under the `kwin` repository. The following code changes show how *Aurorae* can be modified to better recreate the Mac OS 9 platinum look and feel by adding background color to window CTA and window title:

```diff
From 5fa259391ed42621bbd988bc9a06479a0156857d Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Fri, 4 Oct 2024 13:27:40 -0400
Subject: [PATCH] jacks-customizations: customize window decoration

---
 .../kdecorations/aurorae/src/qml/aurorae.qml  | 204 +++++++++++++-----
 1 file changed, 151 insertions(+), 53 deletions(-)

diff --git a/src/plugins/kdecorations/aurorae/src/qml/aurorae.qml b/src/plugins/kdecorations/aurorae/src/qml/aurorae.qml
index 1ef068db26..b4faffcdea 100644
--- a/src/plugins/kdecorations/aurorae/src/qml/aurorae.qml
+++ b/src/plugins/kdecorations/aurorae/src/qml/aurorae.qml
@@ -13,14 +13,14 @@ Decoration {
     property alias decorationMask: maskItem.mask
     property alias supportsMask: backgroundSvg.supportsMask
     Component.onCompleted: {
-        borders.left   = Qt.binding(function() { return Math.max(0, auroraeTheme.borderLeft);});
-        borders.right  = Qt.binding(function() { return Math.max(0, auroraeTheme.borderRight);});
-        borders.top    = Qt.binding(function() { return Math.max(0, auroraeTheme.borderTop);});
+        borders.left   = Qt.binding(function() { return Math.max(0, auroraeTheme.borderLeft - 1);});
+        borders.right  = Qt.binding(function() { return Math.max(0, auroraeTheme.borderRight + decoration.client.maximized ? 3 : 0);});
+        borders.top    = Qt.binding(function() { return Math.max(0, auroraeTheme.borderTop - 7);});
         borders.bottom = Qt.binding(function() { return Math.max(0, auroraeTheme.borderBottom);});
-        maximizedBorders.left   = Qt.binding(function() { return Math.max(0, auroraeTheme.borderLeftMaximized);});
-        maximizedBorders.right  = Qt.binding(function() { return Math.max(0, auroraeTheme.borderRightMaximized);});
+        maximizedBorders.left   = Qt.binding(function() { return Math.max(0, auroraeTheme.borderLeftMaximized - 1);});
+        maximizedBorders.right  = Qt.binding(function() { return Math.max(0, auroraeTheme.borderRightMaximized + decoration.client.maximized ? 3 : 0);});
         maximizedBorders.bottom = Qt.binding(function() { return Math.max(0, auroraeTheme.borderBottomMaximized);});
-        maximizedBorders.top    = Qt.binding(function() { return Math.max(0, auroraeTheme.borderTopMaximized);});
+        maximizedBorders.top    = Qt.binding(function() { return Math.max(0, auroraeTheme.borderTopMaximized - 7);});
         padding.left   = auroraeTheme.paddingLeft;
         padding.right  = auroraeTheme.paddingRight;
         padding.bottom = auroraeTheme.paddingBottom;
@@ -58,7 +58,7 @@ Decoration {
         imagePath: backgroundSvg.imagePath
         prefix: "decoration"
         opacity: shown ? 1 : 0
-        enabledBorders: decoration.client.maximized ? KSvg.FrameSvg.NoBorder : KSvg.FrameSvg.TopBorder | KSvg.FrameSvg.BottomBorder | KSvg.FrameSvg.LeftBorder | KSvg.FrameSvg.RightBorder
+        enabledBorders: KSvg.FrameSvg.TopBorder | KSvg.FrameSvg.BottomBorder | KSvg.FrameSvg.LeftBorder | KSvg.FrameSvg.RightBorder
         Behavior on opacity {
             enabled: root.animate
             NumberAnimation {
@@ -125,52 +125,52 @@ Decoration {
             }
         }
     }
-    AuroraeButtonGroup {
-        id: leftButtonGroup
-        buttons: options.titleButtonsLeft
-        width: childrenRect.width
-        animate: root.animate
-        anchors {
-            left: root.left
-            leftMargin: decoration.client.maximized ? auroraeTheme.titleEdgeLeftMaximized : (auroraeTheme.titleEdgeLeft + root.padding.left)
-        }
-    }
-    AuroraeButtonGroup {
-        id: rightButtonGroup
-        buttons: options.titleButtonsRight
-        width: childrenRect.width
-        animate: root.animate
-        anchors {
-            right: root.right
-            rightMargin: decoration.client.maximized ? auroraeTheme.titleEdgeRightMaximized : (auroraeTheme.titleEdgeRight + root.padding.right)
-        }
-    }
-    Text {
-        id: caption
-        text: decoration.client.caption
-        textFormat: Text.PlainText
-        horizontalAlignment: auroraeTheme.horizontalAlignment
-        verticalAlignment: auroraeTheme.verticalAlignment
-        elide: Text.ElideRight
-        height: Math.max(auroraeTheme.titleHeight, auroraeTheme.buttonHeight * auroraeTheme.buttonSizeFactor)
-        color: decoration.client.active ? auroraeTheme.activeTextColor : auroraeTheme.inactiveTextColor
-        font: options.titleFont
-        renderType: Text.NativeRendering
-        anchors {
-            left: leftButtonGroup.right
-            right: rightButtonGroup.left
-            top: root.top
-            topMargin: decoration.client.maximized ? auroraeTheme.titleEdgeTopMaximized : (auroraeTheme.titleEdgeTop + root.padding.top)
-            leftMargin: auroraeTheme.titleBorderLeft
-            rightMargin: auroraeTheme.titleBorderRight
-        }
-        Behavior on color {
-            enabled: root.animate
-            ColorAnimation {
-                duration: auroraeTheme.animationTime
-            }
-        }
-    }
+//    AuroraeButtonGroup {
+//        id: leftButtonGroup
+//        buttons: options.titleButtonsLeft
+//        width: childrenRect.width
+//        animate: root.animate
+//        anchors {
+//            left: root.left
+//            leftMargin: decoration.client.maximized ? auroraeTheme.titleEdgeLeftMaximized : (auroraeTheme.titleEdgeLeft + root.padding.left)
+//        }
+//    }
+//    AuroraeButtonGroup {
+//        id: rightButtonGroup
+//        buttons: options.titleButtonsRight
+//        width: childrenRect.width
+//        animate: root.animate
+//        anchors {
+//            right: root.right
+//            rightMargin: decoration.client.maximized ? auroraeTheme.titleEdgeRightMaximized : (auroraeTheme.titleEdgeRight + root.padding.right)
+//        }
+//    }
+//    Text {
+//        id: caption
+//        text: decoration.client.caption
+//        textFormat: Text.PlainText
+//        horizontalAlignment: auroraeTheme.horizontalAlignment
+//        verticalAlignment: auroraeTheme.verticalAlignment
+//        elide: Text.ElideRight
+//        height: Math.max(auroraeTheme.titleHeight, auroraeTheme.buttonHeight * auroraeTheme.buttonSizeFactor)
+//        color: decoration.client.active ? auroraeTheme.activeTextColor : auroraeTheme.inactiveTextColor
+//        font: options.titleFont
+//        renderType: Text.NativeRendering
+//        anchors {
+//            left: leftButtonGroup.right
+//            right: rightButtonGroup.left
+//            top: root.top
+//            topMargin: decoration.client.maximized ? auroraeTheme.titleEdgeTopMaximized : (auroraeTheme.titleEdgeTop + root.padding.top)
+//            leftMargin: auroraeTheme.titleBorderLeft
+//            rightMargin: auroraeTheme.titleBorderRight
+//        }
+//        Behavior on color {
+//            enabled: root.animate
+//            ColorAnimation {
+//                duration: auroraeTheme.animationTime
+//            }
+//        }
+//    }
     KSvg.FrameSvgItem {
         id: innerBorder
         anchors {
@@ -195,6 +195,104 @@ Decoration {
             }
         }
     }
+
+    Rectangle {
+        id: leftButtonGroup
+        height: childrenRect.height
+        width: childrenRect.width + 6
+        anchors {
+            top: root.top
+            left: root.left
+            topMargin: 2
+            rightMargin: 0
+            bottomMargin: 0
+            leftMargin: 2
+        }
+        color: decoration.client.active ? "#CCCCCC" : "#DDDDDD"
+        AuroraeButtonGroup {
+            id: leftButtonGroupCta
+            buttons: options.titleButtonsLeft
+            height: childrenRect.height
+            width: childrenRect.width
+            anchors {
+                top: parent.top
+                horizontalCenter: parent.horizontalCenter
+                topMargin: 1
+                rightMargin: 1
+                bottomMargin: 1
+                leftMargin: 1
+            }
+            animate: root.animate
+        }
+    }
+    Rectangle {
+        id: rightButtonGroup
+        height: childrenRect.height
+        width: childrenRect.width + 6
+        anchors {
+            top: root.top
+            right: root.right
+            topMargin: 2
+            rightMargin: 4
+            bottomMargin: 0
+            leftMargin: 0
+        }
+        color: decoration.client.active ? "#CCCCCC" : "#DDDDDD"
+        AuroraeButtonGroup {
+              id: rightButtonGroupCta
+              buttons: options.titleButtonsRight
+              height: childrenRect.height
+              width: childrenRect.width
+              anchors {
+                  top: parent.top
+                  horizontalCenter: parent.horizontalCenter
+                  topMargin: 1
+                  rightMargin: 1
+                  bottomMargin: 1
+                  leftMargin: 1
+              }
+              animate: root.animate
+          }
+    }
+    Rectangle {
+        id: caption
+        height: 15
+        width: captionMetrics.width + 15
+        anchors {
+            horizontalCenter: parent.horizontalCenter
+            //left: leftButtonGroup.right
+            //right: rightButtonGroup.left
+            top: root.top
+            topMargin: auroraeTheme.titleEdgeTop + root.padding.top + 2
+            leftMargin: auroraeTheme.titleBorderLeft
+            rightMargin: auroraeTheme.titleBorderRight
+        }
+        color: decoration.client.active ? "#CCCCCC" : "#DDDDDD"
+        Text {
+            id: captionText
+            text: decoration.client.caption
+            textFormat: Text.PlainText
+            horizontalAlignment: auroraeTheme.horizontalAlignment
+            verticalAlignment: auroraeTheme.verticalAlignment
+            elide: Text.ElideRight
+            color: decoration.client.active ? auroraeTheme.activeTextColor : auroraeTheme.inactiveTextColor
+            //font: options.titleFont
+            font.pixelSize: 12
+            renderType: Text.NativeRendering
+            anchors.centerIn: parent
+            Behavior on color {
+                enabled: root.animate
+                ColorAnimation {
+                    duration: auroraeTheme.animationTime
+                }
+            }
+        }
+        TextMetrics {
+            id: captionMetrics
+            text: decoration.client.caption
+            font: options.titleFont
+        }
+    }
     KSvg.FrameSvgItem {
         id: innerBorderInactive
         anchors {
-- 
2.47.0
```

See above to recompile and update `kwin`

















# Customize application style

Application style affects the UI elements within a window frame

- including the styling for window scrollbar
- including the styling for applications' UI elements



*kvantum* based (*i.e.* not *Breeze*) application styles can be downloaded and installed from the KDE store

- Instead of drawing UI components programatically, an *kvantum* customization draws UI components by injecting .svg files, giving the customization a richer look and feel
- *kvantum* customizations are stored under `~/.config/Kvantum`





##### install `kvantum`

```shell
$ sudo dnf install kvantum
```





##### install a *kvantum* customization

For example, download and unzip the Mac OS 9 (Colors Kvantum) customization from the KDE store, ref: [link](https://store.kde.org/p/1766812)



Apply the customization through "Kvantum Manager":

```shell
$ kvantummanager
```

Then choose "Select a Kvantum theme folder"



Choose kvantum as the application style engine:

Go to "System Settings" -> "Colors and Themes" -> "Application Style" -> "kvantum"





##### minor improvement to the Mac OS 9 "Colors Kvantum" customization

```shell
$ atom ~/.config/Kvantum/Mac9KvantumClassic/Mac9KvantumClassic.kvconfig
```

Modify this line

```shell
inactive.highlight.text.color=white
```

*n.b.* when editing desktop items, the font color for selected text in the editor is white (on white), hence the font color will be modified when customizing `plasma-desktop`.





##### font improvement to the Mac OS 9 "Colors Kvantum" customization

- install the "Virtue" font file to resemble the "Charcoal" font type, ref: [link](http://www.scootergraphics.com/virtue/)
  - *n.b.* download and unzip the "Windows 95" version
  - add the font file under "System Settings" -> "Text & Fonts" -> "Font Management" -> "Install from file"
- apply the "Virtue" font type
  - under "System Settings" -> "Text & Fonts" -> "Fonts"
  - only apply the font type to "General" and "Toolbar"

*n.b.* the font does has spacing issues when wrapped, hence text-wrapping will be disabled when customizing `plasma-desktop`.

















# Customize plasma style

Plasma style affects panel





##### Install a plasma style

Under "System Settings" -> "Colors & Themes" -> "Plasma Style" -> "Get New"

For example, switching to "Maia Transparent" and then modify menu item hover state to match Mac OS 9

```shell
$ cd ~/.local/share/plasma/desktoptheme
$ git clone git@github.com:kdha200501/jacks-kde-plasma-style.git
$ mv jacks-kde-plasma-style.git Maia_Transparent
```

















# Customize `Dolphin`

##### Setup development for `Dolphin`

```shell
$ cd ~/Downloads
$ git clone https://invent.kde.org/system/dolphin.git

# branch off of the correct version
$ cd dolphin
$ git fetch --prune
$ dolphin --version
$ git checkout v24.11.70
$ git checkout -b jacks-customizations

# install dependencies
$ mkdir build
$ cd build
$ sudo dnf builddep dolphin
$ cmake ..
```





##### Disable chain edit

```diff
From e08124a3067f9f7d112bfa832cc4c41796e96996 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Tue, 24 Sep 2024 23:42:52 -0400
Subject: [PATCH] jacks-customizations: disable chain edit

---
 src/kitemviews/private/kitemlistroleeditor.cpp | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/src/kitemviews/private/kitemlistroleeditor.cpp b/src/kitemviews/private/kitemlistroleeditor.cpp
index 895a97aea..1242d9c31 100644
--- a/src/kitemviews/private/kitemlistroleeditor.cpp
+++ b/src/kitemviews/private/kitemlistroleeditor.cpp
@@ -43,7 +43,7 @@ QByteArray KItemListRoleEditor::role() const
 
 void KItemListRoleEditor::setAllowUpDownKeyChainEdit(bool allowChainEdit)
 {
-    m_allowUpDownKeyChainEdit = allowChainEdit;
+    m_allowUpDownKeyChainEdit = false;
 }
 
 bool KItemListRoleEditor::eventFilter(QObject *watched, QEvent *event)
-- 
2.47.0
```





##### Do not convert vertical scroll into horizontal

```diff
From 4930f088906b86b2f13cf21b0a82f7c9c4d671e7 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Tue, 24 Sep 2024 23:47:41 -0400
Subject: [PATCH] jacks-customizations: do not convert vertical scroll into
 horizontal

---
 src/kitemviews/kitemlistcontainer.cpp | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/src/kitemviews/kitemlistcontainer.cpp b/src/kitemviews/kitemlistcontainer.cpp
index 2f9f5d401..7bb7f80bd 100644
--- a/src/kitemviews/kitemlistcontainer.cpp
+++ b/src/kitemviews/kitemlistcontainer.cpp
@@ -184,7 +184,7 @@ void KItemListContainer::wheelEvent(QWheelEvent *event)
         return;
     }
 
-    const bool scrollHorizontally = (qAbs(event->angleDelta().y()) < qAbs(event->angleDelta().x())) || (!verticalScrollBar()->isVisible());
+    const bool scrollHorizontally = (qAbs(event->angleDelta().y()) < qAbs(event->angleDelta().x()));
     KItemListSmoothScroller *smoothScroller = scrollHorizontally ? m_horizontalSmoothScroller : m_verticalSmoothScroller;
 
     smoothScroller->handleWheelEvent(event);
-- 
2.47.0
```





##### Display mouse-over effect when dragging, only

```diff
From 166ce424a10965f3cd720cbc541e92b80f1b16d6 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Wed, 25 Sep 2024 00:11:19 -0400
Subject: [PATCH] jacks-customizations: display mouse-over effect when
 dragging, only

---
 src/kitemviews/kitemlistcontroller.cpp |  2 ++
 src/kitemviews/kitemlistwidget.cpp     | 23 +++++++++++++++++++++--
 src/kitemviews/kitemlistwidget.h       |  4 ++++
 3 files changed, 27 insertions(+), 2 deletions(-)

diff --git a/src/kitemviews/kitemlistcontroller.cpp b/src/kitemviews/kitemlistcontroller.cpp
index 997e6623b..264f04226 100644
--- a/src/kitemviews/kitemlistcontroller.cpp
+++ b/src/kitemviews/kitemlistcontroller.cpp
@@ -854,6 +854,8 @@ bool KItemListController::dragMoveEvent(QGraphicsSceneDragDropEvent *event, cons
                 Q_EMIT itemHovered(index);
             }
 
+            newHoveredWidget->setHighlighted(m_model->canEnterOnHover(index));
+
             if (!m_autoActivationTimer->isActive() && m_autoActivationTimer->interval() >= 0 && m_model->canEnterOnHover(index)) {
                 m_autoActivationTimer->setProperty("index", index);
                 m_autoActivationTimer->start();
diff --git a/src/kitemviews/kitemlistwidget.cpp b/src/kitemviews/kitemlistwidget.cpp
index 4c9f25986..bbdf96c7a 100644
--- a/src/kitemviews/kitemlistwidget.cpp
+++ b/src/kitemviews/kitemlistwidget.cpp
@@ -34,6 +34,7 @@ KItemListWidget::KItemListWidget(KItemListWidgetInformant *informant, QGraphicsI
     , m_selected(false)
     , m_current(false)
     , m_hovered(false)
+    , m_highlighted(false)
     , m_expansionAreaHovered(false)
     , m_alternateBackground(false)
     , m_enabledSelectionToggle(false)
@@ -144,7 +145,11 @@ void KItemListWidget::paint(QPainter *painter, const QStyleOptionGraphicsItem *o
 
             QPainter pixmapPainter(m_hoverCache);
             const QStyle::State activeState(isActiveWindow() && widget->hasFocus() ? QStyle::State_Active | QStyle::State_Enabled : 0);
-            drawItemStyleOption(&pixmapPainter, widget, activeState | QStyle::State_MouseOver | QStyle::State_Item);
+            if(m_highlighted) {
+                drawItemStyleOption(&pixmapPainter, widget, activeState | QStyle::State_Item | QStyle::State_MouseOver);
+            } else {
+                drawItemStyleOption(&pixmapPainter, widget, activeState | QStyle::State_Item);
+            }
         }
 
         const qreal opacity = painter->opacity();
@@ -248,6 +253,10 @@ bool KItemListWidget::isCurrent() const
 
 void KItemListWidget::setHovered(bool hovered)
 {
+    if(!hovered) {
+        m_highlighted = false;
+    }
+
     if (hovered == m_hovered) {
         return;
     }
@@ -290,6 +299,16 @@ bool KItemListWidget::isHovered() const
     return m_hovered;
 }
 
+void KItemListWidget::setHighlighted(bool highlighted)
+{
+    m_highlighted = highlighted;
+}
+
+bool KItemListWidget::isHighlighted() const
+{
+    return m_highlighted;
+}
+
 void KItemListWidget::setExpansionAreaHovered(bool hovered)
 {
     if (hovered == m_expansionAreaHovered) {
@@ -542,7 +561,7 @@ void KItemListWidget::hoverSequenceEnded()
 
 qreal KItemListWidget::hoverOpacity() const
 {
-    return m_hoverOpacity;
+    return 0;
 }
 
 int KItemListWidget::hoverSequenceIndex() const
diff --git a/src/kitemviews/kitemlistwidget.h b/src/kitemviews/kitemlistwidget.h
index fdfe5e78a..a1b693b00 100644
--- a/src/kitemviews/kitemlistwidget.h
+++ b/src/kitemviews/kitemlistwidget.h
@@ -98,6 +98,9 @@ public:
     void setHovered(bool hovered);
     bool isHovered() const;
 
+    void setHighlighted(bool highlighted);
+    bool isHighlighted() const;
+
     void setExpansionAreaHovered(bool hover);
     bool expansionAreaHovered() const;
 
@@ -257,6 +260,7 @@ private:
     bool m_selected;
     bool m_current;
     bool m_hovered;
+    bool m_highlighted;
     bool m_expansionAreaHovered;
     bool m_alternateBackground;
     bool m_enabledSelectionToggle;
-- 
2.47.0
```





##### Interpret ctrl+down as open item signal

```diff
From a3eaa36a881c3d84c740913f68648c85e1dad2d5 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Mon, 30 Sep 2024 22:06:04 -0400
Subject: [PATCH] jacks-customizations: interpret ctrl+down as open item signal

---
 src/dolphinviewcontainer.cpp           |  8 +++++++-
 src/kitemviews/kitemlistcontroller.cpp | 14 ++++++++++++++
 2 files changed, 21 insertions(+), 1 deletion(-)

diff --git a/src/dolphinviewcontainer.cpp b/src/dolphinviewcontainer.cpp
index e55519d04..fb2715426 100644
--- a/src/dolphinviewcontainer.cpp
+++ b/src/dolphinviewcontainer.cpp
@@ -705,7 +705,13 @@ void DolphinViewContainer::slotItemActivated(const KFileItem &item)
         if (modifiers & Qt::ControlModifier && modifiers & Qt::ShiftModifier) {
             Q_EMIT activeTabRequested(url);
         } else if (modifiers & Qt::ControlModifier) {
-            Q_EMIT tabRequested(url);
+            const auto mouseButtons = QGuiApplication::mouseButtons();
+
+            if (mouseButtons & Qt::LeftButton) {
+                Q_EMIT tabRequested(url);
+            } else {
+                setUrl(url);
+            }
         } else if (modifiers & Qt::ShiftModifier) {
             Dolphin::openNewWindow({KFilePlacesModel::convertedUrl(url)}, this);
         } else {
diff --git a/src/kitemviews/kitemlistcontroller.cpp b/src/kitemviews/kitemlistcontroller.cpp
index 264f04226..1ff2cfb46 100644
--- a/src/kitemviews/kitemlistcontroller.cpp
+++ b/src/kitemviews/kitemlistcontroller.cpp
@@ -379,6 +379,20 @@ bool KItemListController::keyPressEvent(QKeyEvent *event)
         break;
 
     case Qt::Key_Down:
+        if(controlPressed) {
+            const KItemSet selectedItems = m_selectionManager->selectedItems();
+            if (selectedItems.count() >= 2) {
+              Q_EMIT itemsActivated(selectedItems);
+            } else if (selectedItems.count() == 1) {
+              Q_EMIT itemActivated(selectedItems.first());
+            } else {
+              Q_EMIT itemActivated(index);
+            }
+
+            event->ignore();
+            return true;
+        }
+
         updateKeyboardAnchor();
         if (shiftPressed && !m_selectionManager->isAnchoredSelectionActive() && m_selectionManager->isSelected(index)) {
             m_selectionManager->beginAnchoredSelection(index);
-- 
2.47.0
```





##### interpret the enter QKeyEvent on file as rename signal

```diff
From 1d60ca0afda8de58dec5e310bd5b3ff74d58655e Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Wed, 2 Oct 2024 20:02:15 -0400
Subject: [PATCH] jacks-customizations: interpret the enter QKeyEvent on file
 as rename signal

---
 src/kitemviews/kitemlistcontroller.cpp | 22 ++++++++++++++--------
 src/kitemviews/kitemlistcontroller.h   |  1 +
 2 files changed, 15 insertions(+), 8 deletions(-)

diff --git a/src/kitemviews/kitemlistcontroller.cpp b/src/kitemviews/kitemlistcontroller.cpp
index 1ff2cfb46..c33b91de8 100644
--- a/src/kitemviews/kitemlistcontroller.cpp
+++ b/src/kitemviews/kitemlistcontroller.cpp
@@ -8,6 +8,7 @@
  */
 
 #include "kitemlistcontroller.h"
+#include "views/dolphinview.h"
 
 #include "kitemlistselectionmanager.h"
 #include "kitemlistview.h"
@@ -32,6 +33,7 @@
 
 KItemListController::KItemListController(KItemModelBase *model, KItemListView *view, QObject *parent)
     : QObject(parent)
+    , m_parent(parent)
     , m_singleClickActivationEnforced(false)
     , m_selectionMode(false)
     , m_selectionTogglePressed(false)
@@ -458,14 +460,18 @@ bool KItemListController::keyPressEvent(QKeyEvent *event)
 
     case Qt::Key_Enter:
     case Qt::Key_Return: {
-        const KItemSet selectedItems = m_selectionManager->selectedItems();
-        if (selectedItems.count() >= 2) {
-            Q_EMIT itemsActivated(selectedItems);
-        } else if (selectedItems.count() == 1) {
-            Q_EMIT itemActivated(selectedItems.first());
-        } else {
-            Q_EMIT itemActivated(index);
-        }
+        // const KItemSet selectedItems = m_selectionManager->selectedItems();
+        // if (selectedItems.count() >= 2) {
+        //     Q_EMIT itemsActivated(selectedItems);
+        // } else if (selectedItems.count() == 1) {
+        //     Q_EMIT itemActivated(selectedItems.first());
+        // } else {
+        //     Q_EMIT itemActivated(index);
+        // }
+
+        // When the KStandardItemListWidget is in edit mode, subsequent Enter/Return QKeyEvent are not captured here
+        DolphinView *dolphinView = qobject_cast<DolphinView *>(m_parent);
+        dolphinView->renameSelectedItems();
         break;
     }
 
diff --git a/src/kitemviews/kitemlistcontroller.h b/src/kitemviews/kitemlistcontroller.h
index fcb971fb7..c0842df51 100644
--- a/src/kitemviews/kitemlistcontroller.h
+++ b/src/kitemviews/kitemlistcontroller.h
@@ -342,6 +342,7 @@ private:
     void startRubberBand();
 
 private:
+    QObject *m_parent;
     bool m_singleClickActivationEnforced;
     bool m_selectionMode;
     bool m_selectionTogglePressed;
-- 
2.47.0
```





##### ensure one focus at a time

```diff
From 57405d252bad064ad3c150a90b0a028c32d9960b Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Tue, 24 Sep 2024 23:52:15 -0400
Subject: [PATCH] jacks-customizations: ensure one focus at a time

---
 src/dolphinmainwindow.cpp             | 10 ++++++++++
 src/dolphinmainwindow.h               |  2 ++
 src/dolphinnavigatorswidgetaction.cpp |  7 +++++++
 src/dolphinnavigatorswidgetaction.h   |  2 ++
 4 files changed, 21 insertions(+)

diff --git a/src/dolphinmainwindow.cpp b/src/dolphinmainwindow.cpp
index 54cd3bf71..ce6fc699d 100644
--- a/src/dolphinmainwindow.cpp
+++ b/src/dolphinmainwindow.cpp
@@ -865,7 +865,10 @@ void DolphinMainWindow::paste()
 
 void DolphinMainWindow::find()
 {
+    KUrlNavigator *navigator = m_activeViewContainer->urlNavigator();
+    navigator->setUrlEditable(false);
     m_activeViewContainer->setSearchModeEnabled(true);
+    m_activeViewContainer->view()->clearSelection();
 }
 
 void DolphinMainWindow::updateSearchAction()
@@ -1124,6 +1127,8 @@ void DolphinMainWindow::replaceLocation()
         navigator->setUrlEditable(true);
         navigator->setFocus();
         lineEdit->selectAll();
+        m_activeViewContainer->setSearchModeEnabled(false);
+        m_activeViewContainer->view()->clearSelection();
     }
 }
 
@@ -3004,4 +3009,9 @@ void DolphinMainWindow::slotDoubleClickViewBackground(Qt::MouseButton button)
     }
 }
 
+void DolphinMainWindow::focusOnDolphinView()
+{
+    m_activeViewContainer->view()->setFocus();
+}
+
 #include "moc_dolphinmainwindow.cpp"
diff --git a/src/dolphinmainwindow.h b/src/dolphinmainwindow.h
index 37994b85a..6f28b749a 100644
--- a/src/dolphinmainwindow.h
+++ b/src/dolphinmainwindow.h
@@ -141,6 +141,8 @@ public:
      */
     void slotDoubleClickViewBackground(Qt::MouseButton button);
 
+    void focusOnDolphinView();
+
 public Q_SLOTS:
     /**
      * Opens each directory in \p dirs in a separate tab. If \a splitView is set,
diff --git a/src/dolphinnavigatorswidgetaction.cpp b/src/dolphinnavigatorswidgetaction.cpp
index f45589dbb..9cf202603 100644
--- a/src/dolphinnavigatorswidgetaction.cpp
+++ b/src/dolphinnavigatorswidgetaction.cpp
@@ -5,6 +5,7 @@
     SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
 */
 
+#include "dolphinmainwindow.h"
 #include "dolphinnavigatorswidgetaction.h"
 
 #include "trash/dolphintrash.h"
@@ -24,6 +25,7 @@
 
 DolphinNavigatorsWidgetAction::DolphinNavigatorsWidgetAction(QWidget *parent)
     : QWidgetAction{parent}
+    , m_parent(parent)
     , m_splitter{new QSplitter(Qt::Horizontal)}
     , m_adjustSpacingTimer{new QTimer(this)}
     , m_viewGeometriesHelper{m_splitter.get(), this}
@@ -208,6 +210,11 @@ QWidget *DolphinNavigatorsWidgetAction::createNavigatorWidget(Side side) const
         },
         Qt::QueuedConnection);
 
+    connect(urlNavigator, &KUrlNavigator::returnPressed, this, [urlNavigator, this]() {
+      DolphinMainWindow *dolphinMainWindow = qobject_cast<DolphinMainWindow *>(m_parent);
+      dolphinMainWindow->focusOnDolphinView();
+    });
+
     auto trailingSpacing = new QWidget{navigatorWidget};
     layout->addWidget(trailingSpacing);
     return navigatorWidget;
diff --git a/src/dolphinnavigatorswidgetaction.h b/src/dolphinnavigatorswidgetaction.h
index 6f068e27d..7143ad409 100644
--- a/src/dolphinnavigatorswidgetaction.h
+++ b/src/dolphinnavigatorswidgetaction.h
@@ -100,6 +100,8 @@ protected:
     void deleteWidget(QWidget *widget) override;
 
 private:
+  QObject *m_parent;
+  
     /**
      * In Left-to-right languages the Primary side will be the left one.
      */
-- 
2.47.0
```





##### Use triangle in tree view

```diff
From 74f1460af60958f0ad9a16cdcb6a2241e32b2d2b Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Mon, 14 Oct 2024 14:25:30 -0400
Subject: [PATCH] jacks-customizations: use triangle in tree view

---
 src/kitemviews/kstandarditemlistwidget.cpp | 62 ++++++++++------------
 1 file changed, 27 insertions(+), 35 deletions(-)

diff --git a/src/kitemviews/kstandarditemlistwidget.cpp b/src/kitemviews/kstandarditemlistwidget.cpp
index fe686d4fe..057de74ea 100644
--- a/src/kitemviews/kstandarditemlistwidget.cpp
+++ b/src/kitemviews/kstandarditemlistwidget.cpp
@@ -1563,41 +1563,6 @@ void KStandardItemListWidget::drawPixmap(QPainter *painter, const QPixmap &pixma
     }
 }
 
-void KStandardItemListWidget::drawSiblingsInformation(QPainter *painter)
-{
-    const int siblingSize = size().height();
-    const int x = (m_expansionArea.left() + m_expansionArea.right() - siblingSize) / 2;
-    QRect siblingRect(x, 0, siblingSize, siblingSize);
-
-    bool isItemSibling = true;
-
-    const QBitArray siblings = siblingsInformation();
-    QStyleOption option;
-    const auto normalColor = option.palette.color(normalTextColorRole());
-    const auto highlightColor = option.palette.color(expansionAreaHovered() ? QPalette::Highlight : normalTextColorRole());
-    for (int i = siblings.count() - 1; i >= 0; --i) {
-        option.rect = siblingRect;
-        option.state = siblings.at(i) ? QStyle::State_Sibling : QStyle::State_None;
-        if (isItemSibling) {
-            option.state |= QStyle::State_Item;
-            if (m_isExpandable) {
-                option.state |= QStyle::State_Children;
-            }
-            if (data().value("isExpanded").toBool()) {
-                option.state |= QStyle::State_Open;
-            }
-            option.palette.setColor(QPalette::Text, highlightColor);
-            isItemSibling = false;
-        } else {
-            option.palette.setColor(QPalette::Text, normalColor);
-        }
-
-        style()->drawPrimitive(QStyle::PE_IndicatorBranch, &option, painter);
-
-        siblingRect.translate(-siblingRect.width(), 0);
-    }
-}
-
 QRectF KStandardItemListWidget::roleEditingRect(const QByteArray &role) const
 {
     const TextInfo *textInfo = m_textInfo.value(role);
@@ -1613,6 +1578,33 @@ QRectF KStandardItemListWidget::roleEditingRect(const QByteArray &role) const
     return rect;
 }
 
+void KStandardItemListWidget::drawSiblingsInformation(QPainter *painter)
+{
+    if (!m_isExpandable) {
+        return;
+    }
+
+    QPolygon rightAngledTriangle;
+    const int x = (m_expansionArea.left() + m_expansionArea.right()) / 2;
+    const double y = size().height() / 2;
+    const double halfHeight = 3;
+    const double halfWidth = halfHeight * sqrt(2);
+    if (data().value("isExpanded").toBool()) {
+        rightAngledTriangle << QPoint(x - halfWidth, y - halfHeight) // Top-left vertex
+                            << QPoint(x + halfWidth, y - halfHeight) // Top-right vertex
+                            << QPoint(x, y + halfHeight); // Bottom vertex
+    } else {
+        rightAngledTriangle << QPoint(x - halfHeight, y - halfWidth) // Bottom vertex
+                            << QPoint(x - halfHeight, y + halfWidth) // Top vertex
+                            << QPoint(x + halfHeight, y); // Right vertex
+    }
+
+    QColor color("#6666cc");
+    QBrush brush(color);
+    painter->setBrush(brush);
+    painter->drawPolygon(rightAngledTriangle);
+}
+
 void KStandardItemListWidget::closeRoleEditor()
 {
     disconnect(m_roleEditor, &KItemListRoleEditor::roleEditingCanceled, this, &KStandardItemListWidget::slotRoleEditingCanceled);
-- 
2.47.0
```





##### Change application icon

```shell
$ inkscape /path/to/origin.svg --export-type="png" --export-filename=/path/to/source/16-apps-org.kde.dolphin.png -w 16 -h 16
```

Then repeat for each size





##### Compile and install `Dolphin`

Compile and test-run

```shell
$ make -j 8
$ ./bin/dolphin &
```

Stop *Dolphin* from System Monitor, and then:

```shell
$ sudo make install
```

















# Customize `kio`

##### Setup development for `kio`

```shell
$ cd ~/Downloads
$ git clone https://invent.kde.org/frameworks/kio.git

# branch off of the correct version
$ cd kio
$ git fetch --prune
$ cat ~/Downloads/dolphin/CMakeLists.txt | grep KF6_MIN_VERSION
$ cat ~/Downloads/plasma-desktop/CMakeLists.txt | grep KF6_MIN_VERSION
$ git checkout v6.6.0

# install dependencies
$ mkdir build
$ cd build
$ sudo dnf install libxslt-devel kf6-karchive-devel.x86_64
$ cmake ..
```





##### Use list view in file dialog

```diff
From d5be572ce7e09426d3708730d9d7c8ce1d296ed0 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Wed, 25 Sep 2024 11:39:54 -0400
Subject: [PATCH] jacks-customizations: use list view in file dialog

---
 src/filewidgets/kdiroperator.cpp           | 28 +++++++--------
 src/filewidgets/kdiroperatordetailview.cpp | 41 +++++++++++++---------
 src/filewidgets/kdiroperatordetailview_p.h | 13 +++++--
 3 files changed, 50 insertions(+), 32 deletions(-)

diff --git a/src/filewidgets/kdiroperator.cpp b/src/filewidgets/kdiroperator.cpp
index f7c8bc642..a4b47e922 100644
--- a/src/filewidgets/kdiroperator.cpp
+++ b/src/filewidgets/kdiroperator.cpp
@@ -1013,12 +1013,12 @@ void KDirOperatorPrivate::updateSorting(QDir::SortFlags sort)
     // - provide a signal 'sortingChanged()'
     // - connect KDirOperatorDetailView() with this signal and update the
     //   header internally
-    QTreeView *treeView = qobject_cast<QTreeView *>(m_itemView);
+    KDirOperatorDetailView *treeView = qobject_cast<KDirOperatorDetailView *>(m_itemView);
     if (treeView != nullptr) {
-        QHeaderView *headerView = treeView->header();
-        headerView->blockSignals(true);
-        headerView->setSortIndicator(sortColumn(), sortOrder());
-        headerView->blockSignals(false);
+        // QHeaderView *headerView = treeView->header();
+        // headerView->blockSignals(true);
+        // headerView->setSortIndicator(sortColumn(), sortOrder());
+        // headerView->blockSignals(false);
     }
 
     assureVisibleSelection();
@@ -1634,13 +1634,13 @@ void KDirOperator::setViewInternal(QAbstractItemView *view)
     // d->itemView->setDropOptions(d->dropOptions);
 
     // first push our settings to the view, then listen for changes from the view
-    QTreeView *treeView = qobject_cast<QTreeView *>(d->m_itemView);
+    KDirOperatorDetailView *treeView = qobject_cast<KDirOperatorDetailView *>(d->m_itemView);
     if (treeView) {
-        QHeaderView *headerView = treeView->header();
-        headerView->setSortIndicator(d->sortColumn(), d->sortOrder());
-        connect(headerView, &QHeaderView::sortIndicatorChanged, this, [this](int logicalIndex, Qt::SortOrder order) {
-            d->synchronizeSortingState(logicalIndex, order);
-        });
+        // QHeaderView *headerView = treeView->header();
+        // headerView->setSortIndicator(d->sortColumn(), d->sortOrder());
+        // connect(headerView, &QHeaderView::sortIndicatorChanged, this, [this](int logicalIndex, Qt::SortOrder order) {
+        //     d->synchronizeSortingState(logicalIndex, order);
+        // });
     }
 
     connect(d->m_itemView, &QAbstractItemView::activated, this, [this](QModelIndex index) {
@@ -1684,7 +1684,7 @@ void KDirOperator::setViewInternal(QAbstractItemView *view)
     // needs to be done here, and not in createView, since we can be set an external view
     d->m_decorationMenu->setEnabled(qobject_cast<QListView *>(d->m_itemView));
 
-    d->m_shouldFetchForItems = qobject_cast<QTreeView *>(view);
+    d->m_shouldFetchForItems = qobject_cast<KDirOperatorDetailView *>(view);
     if (d->m_shouldFetchForItems) {
         connect(d->m_dirModel, &KDirModel::expand, this, [this](QModelIndex index) {
             d->slotExpandToUrl(index);
@@ -1731,7 +1731,7 @@ void KDirOperator::setDirLister(KDirLister *lister)
     d->m_dirModel->setDirLister(d->m_dirLister);
     d->m_dirModel->setDropsAllowed(KDirModel::DropOnDirectory);
 
-    d->m_shouldFetchForItems = qobject_cast<QTreeView *>(d->m_itemView);
+    d->m_shouldFetchForItems = qobject_cast<KDirOperatorDetailView *>(d->m_itemView);
     if (d->m_shouldFetchForItems) {
         connect(d->m_dirModel, &KDirModel::expand, this, [this](QModelIndex index) {
             d->slotExpandToUrl(index);
@@ -2789,7 +2789,7 @@ void KDirOperatorPrivate::slotChangeDecorationPosition()
 
 void KDirOperatorPrivate::slotExpandToUrl(const QModelIndex &index)
 {
-    QTreeView *treeView = qobject_cast<QTreeView *>(m_itemView);
+    KDirOperatorDetailView *treeView = qobject_cast<KDirOperatorDetailView *>(m_itemView);
 
     if (!treeView) {
         return;
diff --git a/src/filewidgets/kdiroperatordetailview.cpp b/src/filewidgets/kdiroperatordetailview.cpp
index 8bbd3e42c..e5a550ffd 100644
--- a/src/filewidgets/kdiroperatordetailview.cpp
+++ b/src/filewidgets/kdiroperatordetailview.cpp
@@ -18,7 +18,7 @@
 #include <QScrollBar>
 
 KDirOperatorDetailView::KDirOperatorDetailView(QWidget *parent)
-    : QTreeView(parent)
+    : QListView(parent)
     , m_hideDetailColumns(false)
 {
     setRootIsDecorated(false);
@@ -37,6 +37,15 @@ KDirOperatorDetailView::KDirOperatorDetailView(QWidget *parent)
     horizontalScrollBar()->setSingleStep(singleStep);
 }
 
+void KDirOperatorDetailView::setRootIsDecorated(bool b) {}
+void KDirOperatorDetailView::setSortingEnabled(bool b) {}
+void KDirOperatorDetailView::setUniformRowHeights(bool b) {}
+void KDirOperatorDetailView::setItemsExpandable(bool b) {}
+void KDirOperatorDetailView::setColumnHidden(int column, bool hide) {}
+void KDirOperatorDetailView::hideColumn(int column) {}
+void KDirOperatorDetailView::expand(const QModelIndex &index) {}
+
+
 KDirOperatorDetailView::~KDirOperatorDetailView()
 {
 }
@@ -65,30 +74,30 @@ bool KDirOperatorDetailView::setViewMode(KFile::FileView viewMode)
     // This allows to have a horizontal scrollbar in case this view is used as
     // a plain treeview instead of cutting off filenames, especially useful when
     // using KDirOperator in horizontally limited parts of an app.
-    if (tree && m_hideDetailColumns) {
-        header()->setSectionResizeMode(QHeaderView::ResizeToContents);
-    } else {
-        header()->setSectionResizeMode(QHeaderView::Interactive);
-    }
+    // if (tree && m_hideDetailColumns) {
+    //     header()->setSectionResizeMode(QHeaderView::ResizeToContents);
+    // } else {
+    //     header()->setSectionResizeMode(QHeaderView::Interactive);
+    // }
 
     return true;
 }
 
 void KDirOperatorDetailView::initViewItemOption(QStyleOptionViewItem *option) const
 {
-    QTreeView::initViewItemOption(option);
+    QListView::initViewItemOption(option);
     option->textElideMode = Qt::ElideMiddle;
 }
 
 bool KDirOperatorDetailView::event(QEvent *event)
 {
     if (event->type() == QEvent::Polish) {
-        QHeaderView *headerView = header();
-        headerView->setSectionResizeMode(0, QHeaderView::Stretch);
-        headerView->setSectionResizeMode(1, QHeaderView::ResizeToContents);
-        headerView->setSectionResizeMode(2, QHeaderView::ResizeToContents);
-        headerView->setStretchLastSection(false);
-        headerView->setSectionsMovable(false);
+        // QHeaderView *headerView = header();
+        // headerView->setSectionResizeMode(0, QHeaderView::Stretch);
+        // headerView->setSectionResizeMode(1, QHeaderView::ResizeToContents);
+        // headerView->setSectionResizeMode(2, QHeaderView::ResizeToContents);
+        // headerView->setStretchLastSection(false);
+        // headerView->setSectionsMovable(false);
 
         setColumnHidden(KDirModel::Size, m_hideDetailColumns);
         setColumnHidden(KDirModel::ModifiedTime, m_hideDetailColumns);
@@ -103,7 +112,7 @@ bool KDirOperatorDetailView::event(QEvent *event)
         }
     }
 
-    return QTreeView::event(event);
+    return QListView::event(event);
 }
 
 void KDirOperatorDetailView::dragEnterEvent(QDragEnterEvent *event)
@@ -115,7 +124,7 @@ void KDirOperatorDetailView::dragEnterEvent(QDragEnterEvent *event)
 
 void KDirOperatorDetailView::mousePressEvent(QMouseEvent *event)
 {
-    QTreeView::mousePressEvent(event);
+    QListView::mousePressEvent(event);
 
     const QModelIndex index = indexAt(event->pos());
     if (!index.isValid() || (index.column() != KDirModel::Name)) {
@@ -128,7 +137,7 @@ void KDirOperatorDetailView::mousePressEvent(QMouseEvent *event)
 
 void KDirOperatorDetailView::currentChanged(const QModelIndex &current, const QModelIndex &previous)
 {
-    QTreeView::currentChanged(current, previous);
+    QListView::currentChanged(current, previous);
 }
 
 #include "moc_kdiroperatordetailview_p.cpp"
diff --git a/src/filewidgets/kdiroperatordetailview_p.h b/src/filewidgets/kdiroperatordetailview_p.h
index f30ab9482..c3f77ab71 100644
--- a/src/filewidgets/kdiroperatordetailview_p.h
+++ b/src/filewidgets/kdiroperatordetailview_p.h
@@ -7,7 +7,8 @@
 #ifndef KDIROPERATORDETAILVIEW_P_H
 #define KDIROPERATORDETAILVIEW_P_H
 
-#include <QTreeView>
+#include <QListView>
+#include <QModelIndex>
 
 #include <kfile.h>
 
@@ -17,7 +18,7 @@ class QAbstractItemModel;
  * Default detail view for KDirOperator using
  * custom resizing options and columns.
  */
-class KDirOperatorDetailView : public QTreeView
+class KDirOperatorDetailView : public QListView
 {
     Q_OBJECT
 
@@ -30,6 +31,14 @@ public:
      */
     virtual bool setViewMode(KFile::FileView viewMode);
 
+    void setRootIsDecorated(bool b);
+    void setSortingEnabled(bool b);
+    void setUniformRowHeights(bool b);
+    void setItemsExpandable(bool b);
+    void setColumnHidden(int column, bool hide);
+    void hideColumn(int column);
+    void expand(const QModelIndex &index);
+
 protected:
     void initViewItemOption(QStyleOptionViewItem *option) const override;
 
-- 
2.47.0
```





##### Disable mouse over effect

```diff
From 1df36fb876828f5a9db765b46f1fa18c1a015bdf Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Fri, 27 Sep 2024 09:28:04 -0400
Subject: [PATCH] jacks-customizations: disable mouse over effect

---
 src/filewidgets/kfileplacesview.cpp | 17 +++++++++++++----
 src/filewidgets/kfileplacesview.h   |  1 +
 src/widgets/kfileitemdelegate.cpp   |  4 +++-
 3 files changed, 17 insertions(+), 5 deletions(-)

diff --git a/src/filewidgets/kfileplacesview.cpp b/src/filewidgets/kfileplacesview.cpp
index dd4830353..ac8ad757d 100644
--- a/src/filewidgets/kfileplacesview.cpp
+++ b/src/filewidgets/kfileplacesview.cpp
@@ -131,12 +131,12 @@ void KFilePlacesViewDelegate::paint(QPainter *painter, const QStyleOptionViewIte
         painter->setOpacity(painter->opacity() * 0.6);
     }
 
-    if (!m_showHoverIndication) {
-        opt.state &= ~QStyle::State_MouseOver;
-    }
+    // if (!m_showHoverIndication) {
+    //     opt.state &= ~QStyle::State_MouseOver;
+    // }
 
     if (opt.state & QStyle::State_MouseOver) {
-        if (index == m_hoveredHeaderArea) {
+        if (index == m_hoveredHeaderArea || !m_view->isDragging()) {
             opt.state &= ~QStyle::State_MouseOver;
         }
     }
@@ -1057,6 +1057,15 @@ bool KFilePlacesView::allPlacesShown() const
     return d->m_showAll;
 }
 
+bool KFilePlacesView::isDragging() const
+{
+    // unfortunately, KIO does not support dropping on top of a place item (to move file/folder),
+    // so, there's no point of highlighting the place item when dragging
+    // return d->m_dragging;
+
+    return false;
+}
+
 void KFilePlacesView::setShowAll(bool showAll)
 {
     KFilePlacesModel *placesModel = qobject_cast<KFilePlacesModel *>(model());
diff --git a/src/filewidgets/kfileplacesview.h b/src/filewidgets/kfileplacesview.h
index d52931fda..f28a3600a 100644
--- a/src/filewidgets/kfileplacesview.h
+++ b/src/filewidgets/kfileplacesview.h
@@ -46,6 +46,7 @@ public:
      * @since 5.91
      */
     bool allPlacesShown() const;
+    bool isDragging() const;
 
     /**
      * If \a enabled is true, it is allowed dropping items
diff --git a/src/widgets/kfileitemdelegate.cpp b/src/widgets/kfileitemdelegate.cpp
index 768268fa9..6e24b43d4 100644
--- a/src/widgets/kfileitemdelegate.cpp
+++ b/src/widgets/kfileitemdelegate.cpp
@@ -1130,7 +1130,7 @@ void KFileItemDelegate::paint(QPainter *painter, const QStyleOptionViewItem &opt
 
     // Check if the item is being animated
     // ========================================================================
-    KIO::AnimationState *state = d->animationState(opt, index, view);
+    KIO::AnimationState *state = nullptr;
     KIO::CachedRendering *cache = nullptr;
     qreal progress = ((opt.state & QStyle::State_MouseOver) && index.column() == KDirModel::Name) ? 1.0 : 0.0;
     const QPoint iconPos = d->iconPosition(opt);
@@ -1296,6 +1296,8 @@ void KFileItemDelegate::paint(QPainter *painter, const QStyleOptionViewItem &opt
         icon = d->applyHoverEffect(icon);
     }
 
+    opt.state &= ~QStyle::State_MouseOver;
+
     style->drawPrimitive(QStyle::PE_PanelItemViewItem, &opt, painter, opt.widget);
     painter->drawPixmap(iconPos, icon);
 
-- 
2.47.0
```





##### One focus at a time

```diff
From b774986181c514aefe2b187f4a1a5fd79f85eac9 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Mon, 30 Sep 2024 09:40:12 -0400
Subject: [PATCH] jacks-customizations: one focus at a time

---
 src/filewidgets/kdiroperator.cpp  |  3 +++
 src/filewidgets/kfilewidget.cpp   |  1 +
 src/filewidgets/kurlnavigator.cpp | 15 +++++++++++++++
 3 files changed, 19 insertions(+)

diff --git a/src/filewidgets/kdiroperator.cpp b/src/filewidgets/kdiroperator.cpp
index a4b47e922..a76e75cde 100644
--- a/src/filewidgets/kdiroperator.cpp
+++ b/src/filewidgets/kdiroperator.cpp
@@ -1757,6 +1757,9 @@ void KDirOperator::setDirLister(KDirLister *lister)
     });
     connect(d->m_dirLister, qOverload<>(&KCoreDirLister::completed), this, [this]() {
         d->slotIOFinished();
+        if(view()) {
+            view()->setFocus();
+        }
     });
     connect(d->m_dirLister, qOverload<>(&KCoreDirLister::canceled), this, [this]() {
         d->slotCanceled();
diff --git a/src/filewidgets/kfilewidget.cpp b/src/filewidgets/kfilewidget.cpp
index 8e4664e30..18e67242b 100644
--- a/src/filewidgets/kfilewidget.cpp
+++ b/src/filewidgets/kfilewidget.cpp
@@ -2111,6 +2111,7 @@ void KFileWidgetPrivate::activateUrlNavigator()
         m_urlNavigator->setUrlEditable(true);
         m_urlNavigator->setFocus();
         lineEdit->selectAll();
+        m_ops->view()->clearSelection();
     }
 }
 
diff --git a/src/filewidgets/kurlnavigator.cpp b/src/filewidgets/kurlnavigator.cpp
index 08cd8ba4a..bf718ec10 100644
--- a/src/filewidgets/kurlnavigator.cpp
+++ b/src/filewidgets/kurlnavigator.cpp
@@ -429,6 +429,10 @@ void KUrlNavigatorPrivate::slotReturnPressed()
         };
         QMetaObject::invokeMethod(q, switchModeFunc, Qt::QueuedConnection);
     }
+
+    if(m_editable) {
+        switchView();
+    }
 }
 
 void KUrlNavigatorPrivate::slotSchemeChanged(const QString &scheme)
@@ -1131,6 +1135,8 @@ void KUrlNavigator::keyPressEvent(QKeyEvent *event)
 {
     if (isUrlEditable() && (event->key() == Qt::Key_Escape)) {
         setUrlEditable(false);
+        d->m_pathBox->setUrl(d->m_coreUrlNavigator->currentLocationUrl());
+        Q_EMIT returnPressed();
     } else {
         QWidget::keyPressEvent(event);
     }
@@ -1204,6 +1210,15 @@ bool KUrlNavigator::eventFilter(QObject *watched, QEvent *event)
     // Avoid the "Properties" action from triggering instead of new tab.
     case QEvent::ShortcutOverride: {
         auto *keyEvent = static_cast<QKeyEvent *>(event);
+
+        // in case the return key is mapped to F2, but that would be the wrong thing to do because,
+        // macOS does not use the enter key to initiate a rename in the file dialog
+        // if (keyEvent->key() == Qt::Key_F2) {
+        //     Q_EMIT d->m_pathBox->returnPressed(d->m_pathBox->currentText());
+        //     event->ignore();
+        //     return false;
+        // }
+
         if ((keyEvent->key() == Qt::Key_Enter || keyEvent->key() == Qt::Key_Return)
             && (keyEvent->modifiers() & Qt::AltModifier || keyEvent->modifiers() & Qt::ShiftModifier)) {
             event->accept();
-- 
2.47.0
```





##### Compiled and install `kio`

```shell
$ make -j 8
$ sudo make install
$ kwin_wayland --replace &
```





##### Debugging

```shell
# note: std::cout.flush(); is needed for real-time log
$ sudo journalctl -b -f
```

















# Customize `plasma-desktop`

##### Setup development for `plasma-desktop`

```shell
$ cd ~/Downloads
$ git clone https://invent.kde.org/plasma/plasma-desktop.git

# branch off of the correct version
$ cd plasma-desktop
$ git fetch --prune
$ plasmashell --version
$ git checkout v6.1.5

# install dependencies
$ mkdir build
$ cd build
$ sudo dnf builddep plasma-desktop
$ cmake ..
```





##### Fix dependency

```diff
From f6524c1d990cd71354430d50fecd8a11105c7f23 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Fri, 11 Oct 2024 14:47:50 -0400
Subject: [PATCH] jacks-customizations: fix dependency

---
 cmake/modules/FindFontNotoColorEmoji.cmake | 22 ++++++++++++++++++++++
 1 file changed, 22 insertions(+)
 create mode 100644 cmake/modules/FindFontNotoColorEmoji.cmake

diff --git a/cmake/modules/FindFontNotoColorEmoji.cmake b/cmake/modules/FindFontNotoColorEmoji.cmake
new file mode 100644
index 000000000..e5dcaa3bb
--- /dev/null
+++ b/cmake/modules/FindFontNotoColorEmoji.cmake
@@ -0,0 +1,22 @@
+# FindFontNotoColorEmoji.cmake
+# Locate the Font Noto Color Emoji library
+
+# Define the name of the package
+set(FontNotoColorEmoji_FOUND FALSE)
+
+# Specify the path to the font file
+set(FontNotoColorEmoji_FONT_PATH "/usr/share/fonts/google-noto-color-emoji-fonts/NotoColorEmoji.ttf")
+
+# Check if the file exists
+if (EXISTS ${FontNotoColorEmoji_FONT_PATH})
+    set(FontNotoColorEmoji_FOUND TRUE)
+endif()
+
+# Provide the results to the parent scope
+if (FontNotoColorEmoji_FOUND)
+    set(FontNotoColorEmoji_FONT ${FontNotoColorEmoji_FONT_PATH} PARENT_SCOPE)
+    message(STATUS "Found Font Noto Color Emoji at ${FontNotoColorEmoji_FONT_PATH}")
+else()
+    message(WARNING "Could not find Font Noto Color Emoji at ${FontNotoColorEmoji_FONT_PATH}")
+endif()
+
-- 
2.47.0
```





##### Do not include background when caching

```diff
From cf198b94811d40208aa7c6361be965a6d2afee5d Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Fri, 11 Oct 2024 17:21:42 -0400
Subject: [PATCH] jacks-customizations: do not include background when caching
 folder item image for dragging

---
 .../desktop/package/contents/ui/FolderItemDelegate.qml     | 7 +++++--
 1 file changed, 5 insertions(+), 2 deletions(-)

diff --git a/containments/desktop/package/contents/ui/FolderItemDelegate.qml b/containments/desktop/package/contents/ui/FolderItemDelegate.qml
index 16e32b884..04e8113b4 100644
--- a/containments/desktop/package/contents/ui/FolderItemDelegate.qml
+++ b/containments/desktop/package/contents/ui/FolderItemDelegate.qml
@@ -32,6 +32,7 @@ Item {
     property Item hoverArea:       loader.item ? loader.item.hoverArea      : null
     property Item frame:           loader.item ? loader.item.frame          : null
     property Item toolTip:         loader.item ? loader.item.toolTip        : null
+    property bool takingSnapshot: false;
     Accessible.name: name
     Accessible.role: Accessible.Canvas
 
@@ -105,8 +106,10 @@ Item {
             onSelectedChanged: Qt.callLater(updateDragImage)
             function updateDragImage() {
                 if (selected && !blank) {
+                    takingSnapshot = true;
                     frameLoader.grabToImage(result => {
                         dir.addItemDragImage(positioner.map(index), main.x + frameLoader.x, main.y + frameLoader.y, frameLoader.width, frameLoader.height, result.image);
+                        takingSnapshot = false;
                     });
                 }
             }
@@ -234,7 +237,7 @@ Item {
                 property string prefix: ""
 
                 sourceComponent: frameComponent
-                active: impl.iconAndLabelsShouldlookSelected || model.selected
+                active: takingSnapshot ? false : impl.iconAndLabelsShouldlookSelected || model.selected
                 asynchronous: true
 
                 width: {
@@ -289,7 +292,7 @@ Item {
                     height: main.GridView.view.iconSize
 
                     opacity: {
-                        if (root.useListViewMode && selectionButton) {
+                        if (root.useListViewMode && selectionButton || takingSnapshot) {
                             return 0.3;
                         }
 
-- 
2.47.0
```





##### Include background when folder is dragged over

```diff
From 7f529c50251d71a92c9eb81378a9e45d615f91e5 Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Fri, 11 Oct 2024 14:45:57 -0400
Subject: [PATCH] jacks-customizations: include background when folder is
 dragged over

---
 .../desktop/package/contents/ui/FolderItemDelegate.qml        | 4 +++-
 containments/desktop/package/contents/ui/FolderView.qml       | 4 +++-
 containments/desktop/plugins/folder/foldermodel.cpp           | 4 ++--
 3 files changed, 8 insertions(+), 4 deletions(-)

diff --git a/containments/desktop/package/contents/ui/FolderItemDelegate.qml b/containments/desktop/package/contents/ui/FolderItemDelegate.qml
index 04e8113b4..e43627ed3 100644
--- a/containments/desktop/package/contents/ui/FolderItemDelegate.qml
+++ b/containments/desktop/package/contents/ui/FolderItemDelegate.qml
@@ -19,6 +19,8 @@ import org.kde.kquickcontrolsaddons 2.0
 Item {
     id: main
 
+    property Item parentItemReference
+
     property int index:          model.index
     property string name:        model.blank ? "" : model.display
     property string nameWrapped: model.blank ? "" : model.displayWrapped
@@ -382,7 +384,7 @@ Item {
                         // get unloaded when items are dragged to a different
                         // place on the desktop.
                         visible: this === frameLoader.item
-                        hovered: impl.iconAndLabelsShouldlookSelected
+                        hovered: impl.iconAndLabelsShouldlookSelected && parentItemReference.dragging && isDir
                         pressed: model.selected
                         active: Window.active
                     }
diff --git a/containments/desktop/package/contents/ui/FolderView.qml b/containments/desktop/package/contents/ui/FolderView.qml
index e057059d0..b4079b45f 100644
--- a/containments/desktop/package/contents/ui/FolderView.qml
+++ b/containments/desktop/package/contents/ui/FolderView.qml
@@ -89,6 +89,7 @@ FocusScope {
         dir.linkHere(sourceUrl);
     }
 
+    // note, this is called by FolderViewDropArea.qml
     function handleDragMove(x, y) {
         var child = childAt(x, y);
 
@@ -451,7 +452,7 @@ FocusScope {
             var leftEdge = Math.min(gridView.contentX, gridView.originX);
 
             if (!item || item.blank) {
-                if (gridView.hoveredItem && !root.containsDrag && (!dialog || !dialog.containsDrag) && !gridView.hoveredItem.popupDialog) {
+                if (!dragging && gridView.hoveredItem && !root.containsDrag && (!dialog || !dialog.containsDrag) && !gridView.hoveredItem.popupDialog) {
                     gridView.hoveredItem = null;
                 }
             } else {
@@ -731,6 +732,7 @@ FocusScope {
                 delegate: FolderItemDelegate {
                     width: gridView.cellWidth
                     height: gridView.cellHeight
+                    parentItemReference: main
                 }
 
                 onContentXChanged: {
diff --git a/containments/desktop/plugins/folder/foldermodel.cpp b/containments/desktop/plugins/folder/foldermodel.cpp
index 5ff981e60..7d63d3158 100644
--- a/containments/desktop/plugins/folder/foldermodel.cpp
+++ b/containments/desktop/plugins/folder/foldermodel.cpp
@@ -281,7 +281,7 @@ QHash<int, QByteArray> FolderModel::staticRoleNames()
     QHash<int, QByteArray> roleNames;
     roleNames[Qt::DisplayRole] = "display";
     roleNames[Qt::DecorationRole] = "decoration";
-    roleNames[BlankRole] = "blank";
+    roleNames[BlankRole] = "blank";// the item.blank alias
     roleNames[SelectedRole] = "selected";
     roleNames[IsDirRole] = "isDir";
     roleNames[IsLinkRole] = "isLink";
@@ -1341,7 +1341,7 @@ QVariant FolderModel::data(const QModelIndex &index, int role) const
     }
 
     if (role == BlankRole) {
-        return m_dragIndexes.contains(index);
+        return m_dragIndexes.contains(index);//ref source of truth for item.blank
     } else if (role == SelectedRole) {
         return m_selectionModel->isSelected(index);
     } else if (role == IsDirRole) {
-- 
2.47.0
```





##### Add shortcuts

```diff
From 84fb7de2179d2215fc6167601cef8059378d652f Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Fri, 11 Oct 2024 17:06:13 -0400
Subject: [PATCH] jacks-customizations: add shortcuts

---
 .../package/contents/ui/FolderView.qml        |  31 +++--
 .../desktop/plugins/folder/foldermodel.cpp    |  39 +++++++
 .../desktop/plugins/folder/foldermodel.h      |   2 +
 .../desktop/plugins/folder/shortcut.cpp       | 106 +++++++++++++-----
 .../desktop/plugins/folder/shortcut.h         |   4 +
 5 files changed, 150 insertions(+), 32 deletions(-)

diff --git a/containments/desktop/package/contents/ui/FolderView.qml b/containments/desktop/package/contents/ui/FolderView.qml
index b4079b45f..0ca7cd566 100644
--- a/containments/desktop/package/contents/ui/FolderView.qml
+++ b/containments/desktop/package/contents/ui/FolderView.qml
@@ -974,13 +974,13 @@ FocusScope {
                 Behavior on contentX { id: smoothX; enabled: false; SmoothedAnimation { velocity: 700 } }
                 Behavior on contentY { id: smoothY; enabled: false; SmoothedAnimation { velocity: 700 } }
 
-                Keys.onReturnPressed: event => {
-                    if (event.modifiers === Qt.AltModifier) {
-                        dir.openPropertiesDialog();
-                    } else {
-                        runOrCdSelected();
-                    }
-                }
+                //Keys.onReturnPressed: event => {
+                //    if (event.modifiers === Qt.AltModifier) {
+                //        dir.openPropertiesDialog();
+                //    } else {
+                //        runOrCdSelected();
+                //    }
+                //}
 
                 Keys.onEnterPressed: event => Keys.returnPressed(event)
 
@@ -1007,6 +1007,11 @@ FocusScope {
                         installAsEventFilterFor(gridView);
                     }
 
+                    // convention over configuration, the convention is "on<Q_Signal name>"
+                    onOpen: {
+                        gridView.runOrCdSelected();
+                    }
+
                     onDeleteFile: {
                         dir.deleteSelected();
                     }
@@ -1015,6 +1020,10 @@ FocusScope {
                         rename();
                     }
 
+                    onDuplicate: {
+                        dir.duplicateSelected();
+                    }
+
                     onMoveToTrash: {
                         const action = dir.action("trash");
                         if (action && action.enabled) {
@@ -1022,9 +1031,17 @@ FocusScope {
                         }
                     }
 
+                    onViewProperties: {
+                        dir.openPropertiesDialog();
+                    }
+
                     onCreateFolder: {
                         model.createFolder();
                     }
+
+                    onRunHome: {
+                        dir.runHome();
+                    }
                 }
 
                 Keys.onPressed: event => {
diff --git a/containments/desktop/plugins/folder/foldermodel.cpp b/containments/desktop/plugins/folder/foldermodel.cpp
index 7d63d3158..045a53ab5 100644
--- a/containments/desktop/plugins/folder/foldermodel.cpp
+++ b/containments/desktop/plugins/folder/foldermodel.cpp
@@ -807,6 +807,15 @@ void FolderModel::runSelected()
     fileItemActions.runPreferredApplications(items);
 }
 
+void FolderModel::runHome()
+{
+    QUrl url = QUrl::fromLocalFile(QStandardPaths::writableLocation(QStandardPaths::HomeLocation));auto job = new KIO::OpenUrlJob(url);
+    job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
+    job->setShowOpenOrExecuteDialog(false);
+    job->setRunExecutables(false);
+    job->start();
+}
+
 void FolderModel::rename(int row, const QString &name)
 {
     if (row < 0) {
@@ -2116,6 +2125,36 @@ void FolderModel::deleteSelected()
     job->start();
 }
 
+void FolderModel::duplicateSelected()
+{
+    if (!m_selectionModel->hasSelection()) {
+        return;
+    }
+
+    const QMimeDatabase db; // default constructors
+
+    for (const auto &originalURL : selectedUrls()) {
+        // The following source code are copied from the Dolphin file manager
+        const QString originalDirectoryPath = originalURL.adjusted(QUrl::RemoveFilename).path();
+        const QString originalFileName = originalURL.fileName();
+        QString extension = db.suffixForFileName(originalFileName);
+        QUrl duplicateURL = originalURL;
+
+        if (extension.isEmpty()) {
+            duplicateURL.setPath(originalDirectoryPath + i18nc("<filename> copy", "%1 copy", originalFileName));
+        } else {
+            extension = QLatin1String(".") + extension;
+            const QString originalFilenameWithoutExtension = originalFileName.chopped(extension.size());
+            const QString originalExtension = originalFileName.right(extension.size());
+            duplicateURL.setPath(originalDirectoryPath + i18nc("<filename> copy", "%1 copy", originalFilenameWithoutExtension) + originalExtension);
+        }
+
+        KIO::CopyJob *job = KIO::copyAs(originalURL, duplicateURL);
+        job->setAutoRename(true);
+        KIO::FileUndoManager::self()->recordCopyJob(job);
+    }
+}
+
 void FolderModel::undo()
 {
     if (QAction *action = m_actionCollection.action(QStringLiteral("undo"))) {
diff --git a/containments/desktop/plugins/folder/foldermodel.h b/containments/desktop/plugins/folder/foldermodel.h
index 0a2cd6aeb..f54e076ea 100644
--- a/containments/desktop/plugins/folder/foldermodel.h
+++ b/containments/desktop/plugins/folder/foldermodel.h
@@ -192,6 +192,7 @@ public:
 
     Q_INVOKABLE void run(int row);
     Q_INVOKABLE void runSelected();
+    Q_INVOKABLE void runHome();
 
     Q_INVOKABLE void rename(int row, const QString &name);
     Q_INVOKABLE int fileExtensionBoundary(int row);
@@ -237,6 +238,7 @@ public:
     Q_INVOKABLE void copy();
     Q_INVOKABLE void cut();
     Q_INVOKABLE void deleteSelected();
+    Q_INVOKABLE void duplicateSelected();
     Q_INVOKABLE void undo();
     Q_INVOKABLE void refresh();
     Q_INVOKABLE void createFolder();
diff --git a/containments/desktop/plugins/folder/shortcut.cpp b/containments/desktop/plugins/folder/shortcut.cpp
index 591f6f8d3..15206535a 100644
--- a/containments/desktop/plugins/folder/shortcut.cpp
+++ b/containments/desktop/plugins/folder/shortcut.cpp
@@ -16,6 +16,62 @@ ShortCut::ShortCut(QObject *parent)
 {
 }
 
+bool ShortCut::eventFilter(QObject *obj, QEvent *e)
+{
+
+  if (e->type() != QEvent::KeyPress) {
+      return QObject::eventFilter(obj, e);
+  }
+
+  QKeyEvent *keyEvent = static_cast<QKeyEvent *>(e);
+  bool isContrl = keyEvent->modifiers() & Qt::ControlModifier;
+  bool isShift = keyEvent->modifiers() & Qt::ShiftModifier;
+
+  if (isContrl && isShift && keyEvent->key() == Qt::Key_N) {
+      Q_EMIT createFolder();
+      return true;
+  }
+
+  if (isContrl && isShift && keyEvent->key() == Qt::Key_H) {
+      Q_EMIT runHome();
+      return true;
+  }
+
+  if (isContrl && keyEvent->key() == Qt::Key_N) {
+      Q_EMIT runHome();
+      return true;
+  }
+
+  // The reactions to the following signals already checks for the presence of selection
+
+  if (isContrl && keyEvent->key() == Qt::Key_Down) {
+      Q_EMIT open();
+      return true;
+  }
+
+  if (keyEvent->key() == Qt::Key_Enter || keyEvent->key() == Qt::Key_Return) {
+      Q_EMIT renameFile();
+      return true;
+  }
+
+  if (isContrl && keyEvent->key() == Qt::Key_D) {
+      Q_EMIT duplicate();
+      return true;
+  }
+
+  if (isContrl && keyEvent->key() == Qt::Key_Backspace) {
+      Q_EMIT moveToTrash();
+      return true;
+  }
+
+  if (isContrl && keyEvent->key() == Qt::Key_I) {
+      Q_EMIT viewProperties();
+      return true;
+  }
+
+  return QObject::eventFilter(obj, e);
+}
+
 void ShortCut::installAsEventFilterFor(QObject *target)
 {
     if (target) {
@@ -23,28 +79,28 @@ void ShortCut::installAsEventFilterFor(QObject *target)
     }
 }
 
-bool ShortCut::eventFilter(QObject *obj, QEvent *e)
-{
-    if (e->type() == QEvent::KeyPress) {
-        QKeyEvent *keyEvent = static_cast<QKeyEvent *>(e);
-        const int keyInt = keyEvent->modifiers() & ~Qt::KeypadModifier | keyEvent->key();
-        if (KStandardShortcut::deleteFile().contains(QKeySequence(keyInt))) {
-            Q_EMIT deleteFile();
-            return true;
-        }
-        if (KStandardShortcut::renameFile().contains(QKeySequence(keyInt))) {
-            Q_EMIT renameFile();
-            return true;
-        }
-        if (KStandardShortcut::moveToTrash().contains(QKeySequence(keyInt))) {
-            Q_EMIT moveToTrash();
-            return true;
-        }
-        if (KStandardShortcut::createFolder().contains(QKeySequence(keyInt))) {
-            Q_EMIT createFolder();
-            return true;
-        }
-    }
-
-    return QObject::eventFilter(obj, e);
-}
+// bool ShortCut::eventFilter(QObject *obj, QEvent *e)
+// {
+//     if (e->type() == QEvent::KeyPress) {
+//         QKeyEvent *keyEvent = static_cast<QKeyEvent *>(e);
+//         const int keyInt = keyEvent->modifiers() & ~Qt::KeypadModifier | keyEvent->key();
+//         if (KStandardShortcut::deleteFile().contains(QKeySequence(keyInt))) {
+//             Q_EMIT deleteFile();
+//             return true;
+//         }
+//         if (KStandardShortcut::renameFile().contains(QKeySequence(keyInt))) {
+//             Q_EMIT renameFile();
+//             return true;
+//         }
+//         if (KStandardShortcut::moveToTrash().contains(QKeySequence(keyInt))) {
+//             Q_EMIT moveToTrash();
+//             return true;
+//         }
+//         if (KStandardShortcut::createFolder().contains(QKeySequence(keyInt))) {
+//             Q_EMIT createFolder();
+//             return true;
+//         }
+//     }
+//
+//     return QObject::eventFilter(obj, e);
+// }
diff --git a/containments/desktop/plugins/folder/shortcut.h b/containments/desktop/plugins/folder/shortcut.h
index 06e940b3a..b9c73b2a1 100644
--- a/containments/desktop/plugins/folder/shortcut.h
+++ b/containments/desktop/plugins/folder/shortcut.h
@@ -31,9 +31,13 @@ public:
 
 Q_SIGNALS:
     void deleteFile();
+    void open();
     void renameFile();
+    void duplicate();
     void moveToTrash();
+    void viewProperties();
     void createFolder();
+    void runHome();
 
 protected:
     bool eventFilter(QObject *obj, QEvent *e) override;
-- 
2.47.0
```





##### Fix desktop icon label text

```diff
From b62854fe5d29b0ce042f78ae204bf7884be3903d Mon Sep 17 00:00:00 2001
From: Jacks Diao <kdha200501@gmail.com>
Date: Wed, 11 Dec 2024 16:32:35 -0500
Subject: [PATCH] jacks-customizations: fix desktop icon label text

---
 .../desktop/package/contents/ui/FolderItemDelegate.qml         | 2 +-
 containments/desktop/package/contents/ui/RenameEditor.qml      | 3 ++-
 2 files changed, 3 insertions(+), 2 deletions(-)

diff --git a/containments/desktop/package/contents/ui/FolderItemDelegate.qml b/containments/desktop/package/contents/ui/FolderItemDelegate.qml
index 160f9d598..eac8efa18 100644
--- a/containments/desktop/package/contents/ui/FolderItemDelegate.qml
+++ b/containments/desktop/package/contents/ui/FolderItemDelegate.qml
@@ -373,7 +373,7 @@ Item {
 
                     text: main.nameWrapped
                     font.italic: model.isLink
-                    wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
+                    wrapMode: Text.NoWrap
                     horizontalAlignment: Text.AlignHCenter
                 }
 
diff --git a/containments/desktop/package/contents/ui/RenameEditor.qml b/containments/desktop/package/contents/ui/RenameEditor.qml
index 922a96b4b..54ec7a4ac 100644
--- a/containments/desktop/package/contents/ui/RenameEditor.qml
+++ b/containments/desktop/package/contents/ui/RenameEditor.qml
@@ -43,6 +43,8 @@ PlasmaComponents.ScrollView {
 
         rightPadding: root.PlasmaComponents.ScrollBar.vertical.visible ? root.PlasmaComponents.ScrollBar.vertical.width : 0
 
+        color: black
+
         Kirigami.SpellCheck.enabled: false
 
         property Item targetItem: null
@@ -198,4 +200,3 @@ PlasmaComponents.ScrollView {
         }
     }
 }
-
-- 
2.47.0
```





##### Compiled and install `plasma-desktop`

```shell
$ make -j 8
$ sudo make install
$ plasmashell --replace
```

















# Install *Webstorm*

The best *IDE* for front end development



Follow the "Installation instructions" on the download page, ref: [link](https://www.jetbrains.com/webstorm/download/#section=linux)

```shell
$ sudo mkdir /opt/webstorm
$ sudo mv WebStorm-XXX.YYYYY.ZZZ/ /opt/webstorm
$ sudo ln -s /opt/webstorm/WebStorm-XXX.YYYYY.ZZZ/bin/webstorm /usr/bin
$ sudo touch /usr/share/applications/webstorm.desktop
$ sudo vi /usr/share/applications/webstorm.desktop
```

Add the following (borrowed from *Atom*):

```
[Desktop Entry]
Name=Webstorm
GenericName=Integrated Development Environment
Exec=/usr/bin/webstorm
Type=Application
StartupNotify=false
Categories=GTK;Utility;TextEditor;Development;
MimeType=application/javascript;application/json;application/x-httpd-eruby;application/x-httpd-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;application/x-ruby;application/x-bash;application/x-csh;application/x-sh;application/x-zsh;application/x-shellscript;application/x-sql;application/x-tcl;application/xhtml+xml;application/xml;application/xml-dtd;application/xslt+xml;text/coffeescript;text/css;text/html;text/plain;text/xml;text/xml-dtd;text/x-bash;text/x-c++;text/x-c++hdr;text/x-c++src;text/x-c;text/x-chdr;text/x-csh;text/x-csrc;text/x-dsrc;text/x-diff;text/x-go;text/x-java;text/x-java-source;text/x-makefile;text/x-markdown;text/x-objc;text/x-perl;text/x-php;text/x-python;text/x-ruby;text/x-sh;text/x-zsh;text/yaml;inode/directory
StartupWMClass=webstorm
```

















# Install *Google Keep*

```shell
$ sudo touch /usr/share/applications/google-keep.desktop
$ sudo vim /usr/share/applications/google-keep.desktop
```

Add the following:

```
[Desktop Entry]
Comment=Make notes
Exec=\sgoogle-chrome -app=https://keep.google.com
Name=Google Keep
NoDisplay=false
StartupNotify=true
Terminal=false
Type=Application
Categories=Office;Utility
X-KDE-SubstituteUID=false
```

















# Install *Google Calendar*

```shell
$ sudo touch /usr/share/applications/google-calendar.desktop
$ sudo vim /usr/share/applications/google-calendar.desktop
```

Add the following:

```
[Desktop Entry]
Comment=Make notes
Exec=\sgoogle-chrome -app=https://calendar.google.com/calendar
Name=Google Calendar
NoDisplay=false
StartupNotify=true
Terminal=false
Type=Application
Categories=Office;Utility
X-KDE-SubstituteUID=false
```

















# Install Signal

```shell
$ sudo dnf install snapd
$ sudo snap install signal-desktop
```



















# Install jDownloader2

```shell
$ sudo dnf install snapd
$ sudo snap install jdownloader2
```

















# Install VLC

Install VLC from Discovery and then fix code issues:

```shell
$ sudo dnf install x265-libs.x86_64
$ sudo dnf install libde265.x86_64

$ sudo dnf autoremove
$ sudo dnf group upgrade --with-optional Multimedia --allowerasing
```

















# Install `wl-clipboard`

A command line utility to pipe `stdout` into clipboard and pipe clipboard into `stdin`



```shell
$ sudo dnf install wl-clipboard
$ atom ~/.bashrc
```

Add these aliases

```bash
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'
```



*n.b.* `wl-copy` does not accept certain text content *e.g.* the `stdout` produced from `git format-patch`, the workaround is:

```shell
$ pbcopy "$(git format-patch -1 <commit-hash> --stdout)"
```

















# Install Chinese IME

Neither `fcitx` nor `fcitx5` works, so `ibus` it is

```shell
 $ sudo dnf install ibus-pinyin
 $ ibus-setup 
```

Add "Intelligent Pinyin" under "Input Method" -> "Add" -> "Chinese"

















# Bash profile

```shell
alias open=dolphin
alias g=git

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# npm
export NODE_PATH=$(npm -g root)

# put git branch in prompt
function parse_git_branch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

RED="\[\033[01;31m\]"
YELLOW="\[\033[01;33m\]"
GREEN="\[\033[01;32m\]"
BLUE="\[\033[01;34m\]"
NO_COLOR="\[\033[00m\]"

PS1="$GREEN\u$NO_COLOR:$BLUE\w$YELLOW\$(parse_git_branch)$NO_COLOR\$ "


# git completions

# get repo name
function repoNameFromCurrentDirectory() {
   basename $(git config --get remote.origin.url)
}

# extract Jira ticket number from current branch's name
function jiraTicketNumberFromCurrentBranch() {
  [[ -d .git || -d ../.git ]] && git rev-parse --abbrev-ref HEAD \
    | sed 's|feature\/\(.*\)_.*|\U\1|; s|hotfix\/\(.*\)_.*|\U\1|'
}

# custom git auto-completes
function alertAutoComplete() { echo -e "\a\b\c"; }
function backSpaceNTimes() {
  alertAutoComplete
  echo $1 | wc -c | xargs seq | xargs printf '\b%.0s'
}
function printCommitCommand() {
  case $1 in
    gcm)
      cmd='commit -m'
      ;;
    gcam)
      cmd='commit --amend -m'
      ;;
    *)
      cmd=''
  esac
  jiraTicket=$(jiraTicketNumberFromCurrentBranch)
  [ -z "$jiraTicket" ] && echo "$cmd \"\"" || echo "$cmd \"$jiraTicket: \""
}
function printNewBranchCommand() {
  case $(repoNameFromCurrentDirectory) in
    online-booking-x-frontend.git|online-booking-x.git)
      currentBranchType=$(git rev-parse --abbrev-ref HEAD | sed 's|\/\(.*\)||')
      case $currentBranchType in
	master)
	  jiraRrefix='hotfix/BFT-20XXX_PascalCase'
	  ;;
        develop)
          jiraRrefix='feature/BFT-20XXX_PascalCase'
          ;;
        feature)
          jiraRrefix='feature/BFT-20XXX_PascalCase'
          ;;
        release)
          jiraRrefix='feature/BFT-20XXX_PascalCase'
          ;;
        *)
          jiraRrefix=''
      esac
      ;;
    b4ttablet.git)
      jiraRrefix='bft-'
      ;;
    mobilebooking.git)
      jiraRrefix='ob-'
      ;;
    *)
      jiraRrefix=''
  esac
  echo "checkout -b $jiraRrefix"
}
function printCopyCommand() {
    currentBranchName=$(git rev-parse --abbrev-ref HEAD)
    echo "printf \"$currentBranchName\" | pbcopy"
}
function printPullOriginCommand() {
    currentBranchName=$(git rev-parse --abbrev-ref HEAD)
    echo "pull origin $currentBranchName"
}
function printLogCommand() {
    currentBranchName=$(git rev-parse --abbrev-ref HEAD)
    remoteBranchHeadHash=$(git log --pretty="format:%h" -n 1 --remotes)
    git show-ref --quiet --verify "refs/remotes/origin/$currentBranchName" &&
         echo "log --pretty=\"format:%h %s\" HEAD --not origin" ||
         echo "log --pretty=\"format:%h %s\" $remoteBranchHeadHash..HEAD"
}
function printResetCommand() {
    currentBranchName=$(git rev-parse --abbrev-ref HEAD)
    remoteBranchName=$(git show-ref --quiet --verify "refs/remotes/origin/$currentBranchName" && echo $currentBranchName || echo "")
    echo "reset --hard origin/$remoteBranchName"
}

alias cbn=:;    complete -F backSpaceNTimes -P '; ' -C printCopyCommand -o nospace cbn
alias nr=:;     complete -F backSpaceNTimes -P '; npm ' -W 'run ' nr

alias gl=:;     complete -F backSpaceNTimes -P '; git ' -C printLogCommand gl
alias glg=commitsBeforeHashOnDevelop;
alias gb=:;     complete -F backSpaceNTimes -P '; git ' -W 'branch ' gb
alias gbd=:;    complete -F backSpaceNTimes -P '; git ' -W 'branch ' -S ' -D' gbd
alias gbm=:;    complete -F backSpaceNTimes -P '; git ' -W 'branch ' -S ' -m' gbm
alias gbr=:;    complete -F backSpaceNTimes -P '; git ' -W 'branch ' -S ' -r' gbr
alias gc=:;     complete -F backSpaceNTimes -P '; git ' -W 'checkout ' gc
alias gcb=:;    complete -F backSpaceNTimes -P '; git ' -C printNewBranchCommand -o nospace gcb
alias gca=:;    complete -F backSpaceNTimes -P '; git ' -W 'commit ' -S ' --amend' gca
alias gcf=:;    complete -F backSpaceNTimes -P '; git ' -W 'commit ' -S ' --fixup=' -o nospace gcf
alias gcm=:;    complete -F backSpaceNTimes -P '; git ' -C printCommitCommand -o nospace gcm
alias gcam=:;   complete -F backSpaceNTimes -P '; git ' -C printCommitCommand -o nospace gcam
alias gaa=:;    complete -F backSpaceNTimes -P '; git ' -W 'add ' -S ' --all && git status' gaa
alias ga=:;     complete -F backSpaceNTimes -P '; git ' -W 'add ' ga
alias gs=:;     complete -F backSpaceNTimes -P '; git ' -W 'status ' gs
alias gri=:;    complete -F backSpaceNTimes -P '; git ' -W 'rebase ' -S ' -i' gri
alias gria=:;   complete -F backSpaceNTimes -P '; git ' -W 'rebase ' -S ' -i --autosquash' gria
alias grc=:;    complete -F backSpaceNTimes -P '; git ' -W 'rebase ' -S ' --continue' grc
alias gra=:;    complete -F backSpaceNTimes -P '; git ' -W 'rebase ' -S ' --abort' gra
alias grs=:;    complete -F backSpaceNTimes -P '; git ' -W 'rebase ' -S ' --skip' grs
alias gr=:;     complete -F backSpaceNTimes -P '; git ' -W 'reset ' -S ' --' gr
alias grh=:;    complete -F backSpaceNTimes -P '; git ' -W 'reset ' -S ' --hard' grh
alias grho=:;   complete -F backSpaceNTimes -P '; git ' -C printResetCommand -o nospace grho
alias grhh=:;   complete -F backSpaceNTimes -P '; git ' -W 'reset ' -S ' --hard HEAD' grhh
alias grsh=:;   complete -F backSpaceNTimes -P '; git ' -W 'reset ' -S ' --soft HEAD' grsh
alias gpo=:;    complete -F backSpaceNTimes -P '; git ' -C printPullOriginCommand gpo
alias gpor=:;   complete -F backSpaceNTimes -P '; git ' -W 'pull ' -S ' origin --rebase ' -o nospace gpor
alias gpfo=:;   complete -F backSpaceNTimes -P '; git ' -W 'push ' -S ' -f origin ' -o nospace gpfo
alias gfo=:;    complete -F backSpaceNTimes -P '; git ' -W 'fetch ' -S ' origin' gfo
alias gfp=:;    complete -F backSpaceNTimes -P '; git ' -W 'fetch ' -S ' --prune' gfp

# custom Angular auto-completes
alias ngc=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' component --change-detection=OnPush --skip-tests=true --module=' -o nospace ngc
alias ngp=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' pipe --skip-tests=true --module=' -o nospace ngp
alias ngm=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' module' ngm
alias ngrm=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' module --routing=true' ngrm
alias ngs=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' service --skip-tests=true' ngs
alias ngd=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' directive --skip-tests=true --module=' -o nospace ngd

# custom find auto-completes
alias fn=:;    complete -F backSpaceNTimes -P '; find ' -W '.' -S ' -type f -name "<name>" -printf "---\n%p:\n" -exec grep -P "<reg>" {} \;' -o nospace fn

_completion_loader git
__git_complete g __git_main
# complete -o bashdefault -o default -o nospace -F _git g

# nginx
alias nginxStart='sudo nginx';
alias nginxStop='sudo nginx -s stop';
alias nginxStatic='cd /etc/nginx';
```

















# Setup development environment

##### Create a self-signed certificate

```shell
```





##### Install *Nginx*

```shell
$ sudo dnf install nginx
$ nginxStart
```

Navigate to http://localhost to confirm



##### Install *Angular*

```shell
$ npm i -g @angular/cli@latest

$ ng new demo

$ cd demo
$ ng serve
```





















​								
