> [!TIP]
>
> This guide is up to date with Fedora 42



# Install Chrome

- Download and install the `.rpm` version of Google Chrome, ref: [link](https://www.google.com/chrome/)

- Enable two finger pinch zoom
  - go to "chrome://flags/#ozone-platform-hint"
  - select "Wayland"

















# Install *Typora*

*Typroa* is hands down the best *Markdown* editor

> [!TIP]
>
> License can be purchased on their website, ref: [link](https://typora.io/)



There is no .rpm release. The easiest way to install is through a unofficial script (ref: [link](https://github.com/RPM-Outpost/typora)):

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

```shell
set whichwrap+=<,>,h,l,[,]
syntax on
```

















# Install *Git*

```shell
$ sudo dnf install git
$ git config --global user.email "user.email@domain.com"
$ git config --global user.name "Firstname Lastname"
$ git config --global core.editor "vim"
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

> [!TIP]
>
> `wl-copy` does not accept certain text content *e.g.* the `stdout` produced from `git format-patch`, the workaround is:

```shell
$ pbcopy "$(git format-patch -1 <commit-hash> --stdout)"
```

















# Install *Atom*

*Atom* is the most hack-able text editor



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





> [!WARNING]
>
> *Atom* is no longer under development and it can no longer be installed in *Fedora* due to missing dependencies. Skip the remaining steps and see *Pulsar* below

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

















# Install *Pulsar*

> [!TIP]
>
> The team behind Pulsar is a community that came about naturally after the announcement of [Atom's Sunset](https://github.blog/2022-06-08-sunsetting-atom/) and decided that they needed to do something about it to keep their favourite editor alive.



Download the .rpm release from *Pulsar* (ref: [link](https://pulsar-edit.dev/download.html#regular-releases)) and install

Install `prettier-atom` and `atom-runner` from the package manager within *Pulsar*



Aliases *Pulsar* as Atom

```shell
$ vim ~/.bashrc
```

Add

```shell
alias atom=pulsar
```



```shell
$ touch ~/.local/share/applications/pulsar.desktop
$ vim ~/.local/share/applications/pulsar.desktop
```

Copy and paste:

```shell
[Desktop Entry]
Name=Atom
Exec=pulsar %F
Icon=pulsar
Type=Application
Categories=Development;
```

















# Use F1 to F12 keys as function keys

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





##### Create a service to run the program upon sleep events

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

> [!WARNING]
>
> update the bit mask to suite the number of cores in your CPU, *e.g.*
>
> - the mask for a 4 Core CPU is `11111110` which equates to `254` in decimal
> - the mask for a 6 Core CPU is `111111111110` which equates to `4094` in decimal





##### Install the service

```shell
$ sudo systemctl enable /opt/fix-long-wake-from-sleep/fix-long-wake-from-sleep.service
$ sudo systemctl status fix-long-wake-from-sleep.service
```

Logs can be found using:

```shell
$ journalctl -t "toggle-core"
```

















# Install Wifi driver

Follow

- this [link](MacBookPro11/readme.md) for MacBookPro11
- this [link](iMac19/readme.md) for iMac19

















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

The colour profile can be extracted from the Apple Bootcamp driver refs: [link 1](https://github.com/patjak/facetimehd/wiki/Extracting-the-sensor-calibration-files) [link 2](https://support.apple.com/kb/DL1837)

> [!IMPORTANT]
>
> The outcome of this extraction step is attached to this guide: [facetime-hd-color-profile-extraction](facetime-hd-color-profile-extraction)

```shell
$ mkdir -p ~/Downloads/facetimehd-color-profile
$ cd ~/Downloads/facetimehd-color-profile
$ mv ../bootcamp5.1.5769.zip ./
$ unzip bootcamp5.1.5769.zip
$ cd ./BootCamp/Drivers/Apple
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

> [!TIP]
>
> - we need `xremap` for remapping keyboard shortcuts
> - we need `fusuma` for remapping gestures to actions
>   - `fusuma` needs  `ydotool` for converting gesture to keyboard shortcuts
>     - `ydotool` needs `ydotoold` for sending keyboard shortcuts





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
$ atom ~/.bashrc
```

Add the following:

```shell
export PATH=$PATH:~/.cargo/bin/
```

```shell
$ source  ~/.bashrc
```





##### Install `xremap`

```shell
$ cargo install xremap --features kde
```

> [!TIP]
>
> note: installs to the current user





##### Configure `xremap`

```shell
$ mkdir ~/.xremap
$ touch ~/.xremap/config.json
$ atom ~/.xremap/config.json
```

Copy and paste:

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
        "only": ["Pulsar", "Atom"]
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
    },
    {
      "name": "Webstorm",
      "application": {
        "only": "jetbrains-webstorm"
      },
      "remap": {
        "Super-C": "Control_L-Shift-C",
        "Alt-KEY_RIGHTBRACE": "Control-Shift_L-KEY_PAGEDOWN",
        "Alt-KEY_LEFTBRACE": "Control-Shift_L-KEY_PAGEUP"
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

> [!TIP]
>
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

Go to "Window Management" -> "Task Switcher" -> "Main"

- set "Forward" to `⌘` + `Tab`
  - it will be recognized as `Ctrl` + `Tab`
- set "Reverse" to `⌘` + `Shift` + `Tab`
  - it will be recognized as `Ctrl` + `Shift` + `Tab`



##### Enumerate applications (instead of windows) in task switcher

Launch "System Settings"

Go to "Window Management" -> "Task Switcher" -> "Main"

- select "Large Icons"
- enable "Only one window per application"

















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
$ sudo dnf5 group install "development-tools"
$ sudo dnf builddep kwin
$ mkdir build
$ cd build
$ cmake ..
```





##### Disable three finger gestures

Three finger gestures must be disabled so that `fusuma` can react to three-finger gestures (if configured)

Copy this patch ([link](patches/kde-kwin/jacks-customizations__disable_three_finger_gestures.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Disable natural swiping

"Natural" is unnatural to me, so...

Copy this patch ([link](patches/kde-kwin/jacks-customizations__disable_natural_swiping.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Compile and install `kwin`

```shell
$ make -j 8
$ sudo make install
$ kwin_wayland --replace &
```





##### Install `ydotool`

ref: [link](https://copr.fedorainfracloud.org/coprs/wef/ydotool/)

```shell
$ sudo dnf copr enable wef/ydotool 
$ sudo dnf install ydotool
```





##### Install `ruby` and its package manager

```shell
$ sudo dnf install ruby
```





##### Install `fusuma`

```shell
$ sudo gem install fusuma
```

> [!TIP]
>
> note: installs globally





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

Copy this patch ([link](patches/libinput/jacks-customizations__disable_three_finger_tap.patch)) and apply

```shell
$ wl-paste | git apply
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
- display the current application's icon at top-left corner
  - right click on panel -> "Show Panel Configuration" -> "Add Widgets" -> "Get New Widgets" -> "Download New Plasma Widgets"
    - search for "Window Title Applet 6 by dhruv8sh"

- display the current application's menu in the panel

- hide date

  ```shell
  $ sudo vim /usr/share/plasma/plasmoids/org.kde.plasma.digitalclock/contents/config/main.xml
  ```

  change to

  ```xml
  <entry name="showDate" type="Bool">
    <label>Whether the date should be shown next to the clock.</label>
    <default>false</default>
  </entry>
  ```

  


















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

> [!TIP]
>
> - including the styling for window title bar and its buttons
> - not including the styling for window boarders
> - not including the styling for window scrollbar
> - not including the styling for applications' UI elements



> [!TIP]
>
> *Aurorae* based (*i.e.* not *Breeze*) window decorations can be downloaded and installed from the KDE store
>
> - Instead of drawing UI components programatically, an *Aurorae* customization draws UI components by injecting .svg files, giving the customization a richer look and feel
> - *Aurorae* customizations are stored under `~/.local/share/aurorae/themes/`





##### Install a window decoration

For example, installing a BeOS decoration

- Under "System Settings" -> "Colors & Themes" - > "Window Decorations" -> "Get New"
  - and then apply "Besot Haiku"

















# Convert the installed decoration into Mac OS 9

Using assets generously provided by Michael Feeney (ref: [link](https://www.figma.com/community/file/966779730364082883/mac-os-9-ui-kit)), we apply the Mac OS 9 platinum design on top of the BeOS decoration

```shell
$ cd ~/.local/share/aurorae/themes
$ git clone git@github.com:kdha200501/jacks-kde-window-decoration.git
$ mv besothaiku tmp
$ mv jacks-kde-window-decoration besothaiku
$ rm -rf tmp
```

Customize title bar buttons

- Under "System Settings" -> "Colors & Themes" -> "Window Decorations" -> "Configure Titlebar Buttons"
  - remove unwanted buttons from title bar and rearrange button positions






##### Customize window decoration

> [!TIP]
>
> Some customizations cannot be made through using .svg files or updating the rc file such as adding background to the window title text. The only option is to modify *Aurorae*.
>
> *Aurorae* is written in QML, and its code base is under the `kwin` repository.



Copy this patch ([link](patches/kde-kwin/jacks-customizations__customize_window_decoration.patch)) and apply to modify *Aurorae* to better recreate the Mac OS 9 platinum look and feel by adding background color to window CTA and window title

```shell
$ wl-paste | git apply
```

See above to recompile and update `kwin`

















# Customize application style

Application style affects the UI elements within a window frame

> [!TIP]
>
> - including the styling for window scrollbar
> - including the styling for applications' UI elements



> [!TIP]
>
> *kvantum* based (*i.e.* not *Breeze*) application styles can be downloaded and installed from the KDE store
>
> - Instead of drawing UI components programatically, an *kvantum* customization draws UI components by injecting .svg files, giving the customization a richer look and feel
> - *kvantum* customizations are stored under `~/.config/Kvantum`





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

> [!TIP]
>
> When editing desktop items, the font color for selected text in the editor is white (on white), hence the font color will be modified when customizing `plasma-desktop`.





##### font improvement to the Mac OS 9 "Colors Kvantum" customization

- install the "Virtue" font file to resemble the "Charcoal" font type, ref: [link](http://www.scootergraphics.com/virtue/)
  - *n.b.* download and unzip the "Windows 95" version
  - add the font file under "System Settings" -> "Text & Fonts" -> "Font Management" -> "Install from file"
- apply the "Virtue" font type
  - under "System Settings" -> "Text & Fonts" -> "Fonts"
  - only apply the font type to "General" and "Toolbar"

> [!TIP]
>
> The font has spacing issues when wrapped, hence text-wrapping will be disabled when customizing `plasma-desktop`.

















# Customize plasma style

Plasma style affects panel





##### Install a plasma style

Under "System Settings" -> "Colors & Themes" -> "Plasma Style" -> "Get New"

For example, switching to "Maia Transparent" and then modify menu item hover state to match Mac OS 9

```shell
$ cd ~/.local/share/plasma/desktoptheme
$ git clone git@github.com:kdha200501/jacks-kde-plasma-style.git
$ mv Maia_Transparent/ Maia_Transparent_Bak/
$ mv jacks-kde-plasma-style/ Maia_Transparent/
$ rm -rf Maia_Transparent_Bak/
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

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__disable_chain_edit.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Do not convert vertical scroll into horizontal

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__do_not_convert_vertical_scroll_into_horizontal.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Display mouse-over effect when dragging, only

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__display_mouse-over_effect_when_dragging,_only.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Interpret ctrl+down as open item signal

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__interpret_ctrl+down_as_open_item_signal.patch)) and apply

```shell
$ wl-paste | git apply
```





##### interpret the enter QKeyEvent on file as rename signal

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__interpret_the_enter_QKeyEvent_on_file_as_rename_signal.patch)) and apply

```shell
$ wl-paste | git apply
```





##### ensure one focus at a time

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__ensure_one_focus_at_a_time.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Use triangle in tree view

Copy this patch ([link](patches/kde-dolphin/jacks-customizations__use_triangle_in_tree_view.patch)) and apply

```shell
$ wl-paste | git apply
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
$ rpm -qa | grep kf6-kio
$ git checkout v6.6.0

# install dependencies
$ mkdir build
$ cd build
$ sudo dnf install libxslt-devel kf6-karchive-devel.x86_64
$ cmake ..
```





##### Use list view in file dialog

Copy this patch ([link](patches/kde-kio/jacks-customizations__use_list_view_in_file_dialog.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Disable mouse over effect

Copy this patch ([link](patches/kde-kio/jacks-customizations__disable_mouse_over_effect.patch)) and apply

```shell
$ wl-paste | git apply
```





##### One focus at a time

Copy this patch ([link](patches/kde-kio/jacks-customizations__one_focus_at_a_time.patch)) and apply

```shell
$ wl-paste | git apply
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





##### Do not include background when caching

Copy this patch ([link](patches/kde-plasma-desktop/jacks-customizations__do_not_include_background_when_caching.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Include background when folder is dragged over

Copy this patch ([link](patches/kde-plasma-desktop/jacks-customizations__include_background_when_folder_is_dragged_over.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Add shortcuts

Copy this patch ([link](patches/kde-plasma-desktop/jacks-customizations__add_shortcuts.patch)) and apply

```shell
$ wl-paste | git apply
```





##### Fix desktop icon label text

Copy this patch ([link](patches/kde-plasma-desktop/jacks-customizations__fix_desktop_icon_label_text.patch)) and apply

```shell
$ wl-paste | git apply
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
$ sudo vim /usr/share/applications/webstorm.desktop
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

Import IDE settings from [kde__webstorm-settings.zip](./kde__webstorm-settings.zip)

















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

















# Install *Zoom*

```shell
$ sudo dnf install zoom_x86_64.rpm
```

















# Install *Signal*

```shell
$ sudo dnf config-manager addrepo --from-repofile=https://download.opensuse.org/repositories/network:/im:/signal/Fedora_$(rpm -E %fedora)/network:im:signal.repo
$ sudo dnf install signal-desktop
```

















# Install *jDownloader2*

```shell
$ sudo dnf install snapd
$ sudo snap install jdownloader2
```

















# Install *VLC*

##### Add free and non free repositories

see ref: [link](https://rpmfusion.org/Configuration)

```shell
$ sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
$ sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

$ sudo dnf install x265-libs.x86_64
$ sudo dnf install libde265.x86_64

$ sudo dnf install vlc
```



##### Fix codec incompatibility with *ffmpeg*

See ref: [link](https://rpmfusion.org/Howto/Multimedia)

```shell
$ sudo dnf swap ffmpeg-free ffmpeg --allowerasing
$ sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
```

















# Install Chinese IME

Neither `fcitx` nor `fcitx5` works, so `ibus` it is

```shell
 $ sudo dnf install ibus-pinyin
 $ ibus-setup 
```

Add "Intelligent Pinyin" under "Input Method" -> "Add" -> "Chinese"

















# Setup development environment

##### Bash profile

```shell
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH
export PATH=$PATH:~/.cargo/bin/

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

alias open=dolphin
alias atom=pulsar
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'
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
alias ngc=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' component --change-detection=OnPush --skip-tests=true --standalone=false --module=' -o nospace ngc
alias ngp=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' pipe --skip-tests=true --standalone=false --module=' -o nospace ngp
alias ngm=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' module' ngm
alias ngrm=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' module --routing=true' ngrm
alias ngs=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' service --skip-tests=true' ngs
alias ngd=:;    complete -F backSpaceNTimes -P '; ng ' -W 'generate ' -S ' directive --skip-tests=true --standalone=false --module=' -o nospace ngd

# custom .Net auto-completes
alias dr=:;     complete -F backSpaceNTimes -P '; dotnet.exe ' -W 'run ' -o nospace dr

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





##### Install *docker*

```shell
$ sudo dnf install -y dnf-plugins-core
$ sudo dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
$ sudo dnf install -y docker-ce docker-ce-cli containerd.io

# launch docker at start up
$ sudo systemctl start docker
$ sudo systemctl enable docker

# let the current user run docker without elevated privillage
$ sudo usermod -aG docker $USER
$ newgrp docker
```





##### Install *Nginx*

```shell
$ sudo dnf install nginx

$ sudo mkdir -p /etc/nginx/ssl/reverse-proxy
$ cd /etc/nginx/ssl/reverse-proxy
$ sudo openssl req -x509 -nodes -days 14608 -newkey rsa:2048 -keyout nginx.key -out nginx.crt

$ sudo vim /etc/nginx/nginx.conf
```

Change to

```nginx
http {
    ...
	
    #include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
    
	...
}
```

```shell
$ sudo mkdir -p /etc/nginx/logs
$ sudo touch /etc/nginx/logs/reverse-proxy.log

$ sudo mkdir -p /etc/nginx/sites-available
$ sudo mkdir -p /etc/nginx/sites-enabled
$ cd /etc/nginx/sites-enabled

$ sudo touch /etc/nginx/sites-available/main.conf
$ sudo ln -s /etc/nginx/sites-available/main.conf ./
$ sudo vim main.conf
```

Copy and paste:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;

    access_log  /etc/nginx/logs/reverse-proxy.log;

    index index.html index.htm;

    ssl_certificate ssl/reverse-proxy/nginx.crt;
    ssl_certificate_key ssl/reverse-proxy/nginx.key;

    # My project configurations here
    include sites-available/my-project/docker.conf;
}
```

Example project configurations:

```nginx
location / {
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-NginX-Proxy true;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_pass http://127.0.0.1:4200/;
    proxy_redirect off;
}
```



















