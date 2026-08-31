# Build *WiiCompiled* (Mario Kart Wii recompilation) with *Retro Rewind*

[WiiCompiled](https://github.com/zydezu/Wiicompiled) is a Mario Kart Wii recompilation. The `build-linux-native.sh` script **decompiles** the game's `main.dol` into portable C++ using a .NET (`dotnet`) translator, then **recompiles** it into a native Linux ELF binary with Clang. Passing `--retro` also translates and builds Retro Rewind 6 into it.




##### Clone the repository

```shell
$ git clone https://github.com/zydezu/Wiicompiled.git Wiicompiled-linux
```




##### Prerequisites

- `dotnet` — required **only** for the decompilation step, which runs once and whose output is cached. On this host it is not a real SDK install: `~/.local/bin/dotnet` is a **shim** that forwards the call into a Docker image,

  ```shell
  $ docker run --rm -v "$PWD:$PWD" -w "$PWD" mcr.microsoft.com/dotnet/sdk:8.0-alpine dotnet ...
  ```

  the `$PWD` bind-mount (to itself, not a fixed path) keeps the paths the translator records in `shards.cmake` / `.S` files valid on the host. Note the container runs as root, so files it writes are root-owned. (Alternatively, install a real SDK with `sudo dnf install dotnet-sdk-8.0`.)

- Clang (the build **requires** Clang, a GCC fallback is not allowed)

  ```shell
  $ sudo dnf install clang
  ```

- A clean PAL `RMCP01` disc image (`ISO`, `WBFS`, `RVZ`, ...) placed at the repo root. The build script will auto-detect it.




##### Install SDL build dependencies

```shell
$ sudo dnf install cmake ninja-build unzip python3\
    libXss-devel libXt-devel
```

> [!TIP]
>
> if `libXss-devel` / `libXt-devel` are not installable, configure CMake with:
>
> ```shell
> -DSDL_X11_XSCRNSAVER=OFF -DSDL_X11_XTEST=OFF
> ```
>
> this disables screensaver inhibit and XTest in the SDL3 build — fine for gameplay.



##### Build

```shell
$ cd Wiicompiled-linux
$ GAME_IMAGE=/home/jacks/Downloads/MarioKartWii.wbfs \
    INTERACTIVE=0 \
    nohup ./build-linux-native.sh --retro > build.log 2>&1 &
```

The script:

1. fetches `nodtool` (first run only) and extracts the disc image into `extracted/DATA/`
2. fetches the full Retro Rewind 6 pack (first `--retro` run, ~1.8 GB) into `PulsarPacks/completed/RetroRewind/RetroRewind6`
3. builds the translator with `dotnet` (the Docker shim), then translates `main.dol` (plus Retro Rewind's `Code.pul`) to C++ in `generated/` — these steps are cached, so re-runs skip straight to the compile
4. configures and compiles everything with CMake + Ninja + Clang into `linux-native-build/`




##### Fix the config paths

The build script writes `UserData/Config.toml`, but if it was generated manually (or before the fix below) the `[paths]` entries may resolve one level short. Paths are relative to the config's own folder (`linux-native-build/UserData/`), so they need `../../` to reach the repo root:

```shell
$ sed -i 's|\.\./extracted/DATA|../../extracted/DATA|; s|\.\./PulsarPacks|../../PulsarPacks|' \
    linux-native-build/UserData/Config.toml
$ grep -A3 '^\[paths\]' linux-native-build/UserData/Config.toml
```

Expected result:

```
[paths]
dvd_root = "../../extracted/DATA"
retro_rewind_root = "../../PulsarPacks/completed/RetroRewind/RetroRewind6"
```




##### Run

```shell
$ ./linux-native-build/WiiCompiled     # base game
$ ./linux-native-build/RetroRewind    # with Retro Rewind
```

No parameters are needed — both binaries read the same `UserData/Config.toml`, which already points at the disc data and the mod.

> [!IMPORTANT]
>
> The `linux-native-build/` folder is not portable on its own. If you move it, take `extracted/` and `PulsarPacks/` along (or re-run with `--install`, `--package`, or `--appimage` for a self-contained copy).




##### Create a launcher for *Retro Rewind*

```shell
$ touch ~/.local/share/applications/MarioKartWii-RetroRewind.desktop
$ vim ~/.local/share/applications/MarioKartWii-RetroRewind.desktop
```

Copy and paste:

```
[Desktop Entry]
Type=Application
Name=Mario Kart Wii — Retro Rewind
GenericName=Mario Kart Wii (recompiled)
Comment=Run the locally compiled Mario Kart Wii (WiiCompiled) build with Retro Rewind
Exec=/home/jacks/projects/Wiicompiled-linux/linux-native-build/RetroRewind
Path=/home/jacks/projects/Wiicompiled-linux/linux-native-build
Icon=/home/jacks/Pictures/icons/MarioKartWii.png
Terminal=false
Categories=Game;ArcadeGame;
Keywords=wiicompiled;mario;kart;wii;mario-kart;retro-rewind;
```

> [!TIP]
>
> `Path=` sets the launch working directory, so keep it pointing at the folder that holds `UserData/Config.toml`, `wii_bootstrap/`, and the binary itself.

> [!TIP]
>
> the `Path=` entry sets the working directory so the app can find `UserData/Config.toml` and the sibling `wii_bootstrap/` folder — keep it pointing at `linux-native-build/`.



##### Kart naming convention

File naming is `<vehicle>-<character>.szs`

- prefix = vehicle class, e.g. `la_bike`=Flame Runner, `la_kart`=Offroader, `lb_bike`=Wario Bike, `lb_kart`=Flame Flyer, `lc_kart`=Piranha Prowler, `sa_bike`=Bullet Bike (S=small, M=medium, L=large class)

  ```
  la_bike = Flame Runner
  la_kart = Offroader
  lb_bike = Wario Bike
  lb_kart = Flame Flyer
  lc_bike = Shooting Star
  lc_kart = Piranha Prowler
  ld_bike = Spear
  ld_kart = Jetsetter
  ldf_bike = Standard Bike L
  ldf_kart = Standard Kart L
  ldf_bike_blue = Standard Bike L (Battle Mode + Blue Team)
  ldf_bike_red = Standard Bike L (Battle Mode + Red Team)
  ldf_kart_blue = Standard Kart L (Battle Mode + Blue Team)
  ldf_kart_red = Standard Kart L (Battle Mode + Red Team)
  le_bike = Phantom
  le_kart = Honeycoupe
  
  ma_bike = Mach Bike
  ma_kart = Classic Dragster
  mb_bike = Sugarscoot
  mb_kart = Wild Wing
  mc_bike = Zip Zip
  mc_kart = Super Blooper
  md_bike = Sneakster
  md_kart = Daytripper
  mdf_bike = Standard Bike M
  mdf_kart = Standard Kart M
  mdf_bike_blue = Standard Bike M (Battle Mode + Blue Team)
  mdf_bike_red = Standard Bike M (Battle Mode + Red Team)
  mdf_kart_blue = Standard Kart M (Battle Mode + Blue Team)
  mdf_kart_red = Standard Kart M (Battle Mode + Red Team)
  me_bike = Dolphin Dasher
  me_kart = Sprinter
  
  sa_bike = Bullet Bike
  sa_kart = Booster Seat
  sb_bike = Bit Bike
  sb_kart = Mini Beast
  sc_bike = Quacker
  sc_kart = Cheep Charger
  sd_bike = Magikruiser
  sd_kart = Tiny Titan
  sdf_bike = Standard Bike S
  sdf_kart = Standard Kart S
  sdf_bike_blue = Standard Bike S (Battle Mode + Blue Team)
  sdf_bike_red = Standard Bike S (Battle Mode + Red Team)
  sdf_kart_blue = Standard Kart S (Battle Mode + Blue Team)
  sdf_kart_red = Standard Kart S (Battle Mode + Red Team)
  se_bike = Jet Bubble
  se_kart = Blue Falcon
  ```

  

- suffix = character code, e.g. `bk`=Dry Bowser, `dk`=Donkey Kong, `fk`=Funky Kong, `kp`=Bowser, `kt`=King Boo, `rs`=Rosalina, `wl`=Waluigi, `wr`=Wario

  ```
  -bds = Baby Daisy
  -bk = Dry Bowser
  -blg = Baby Luigi
  -bmr = Baby Mario
  -bpc = Baby Peach
  -ca = Birdo
  -dd = Diddy Kong
  -dk = Donkey Kong
  -ds = Daisy
  -ds3 = Daisy (Biker Outfit)*
  -fk = Funky Kong
  -jr = Bowser Jr.
  -ka = Dry Bones
  -kk = Toadette
  -ko = Toad
  -kp = Bowser
  -kt = King Boo
  -la_mii_f = Large Mii Outfit A (Female)
  -la_mii_m = Large Mii Outfit A (Male)
  -lb_mii_f = Large Mii Outfit B (Female)
  -lb_mii_m = Large Mii Outfit B (Male)
  -lg = Luigi
  -ma_mii_f = Medium Mii Outfit A (Female)
  -ma_mii_m = Medium Mii Outfit A (Male)
  -mb_mii_f = Medium Outfit B (Female)
  -mb_mii_m = Medium Mii Outfit B (Male)
  -mr = Mario
  -nk = Koopa Troopa
  -pc = Peach
  -pc3 = Peach (Biker Outfit)*
  -rs = Rosalina
  -rs3 = Rosalina (Biker Outfit)*
  -sa_mii_f = Small Mii Outfit A (Female)
  -sa_mii_m = Small Mii Outfit A (Male)
  -sb_mii_f = Small Mii Outfit B (Female)
  -sb_mii_m = Small Mii Outfit B (Male)
  -wl = Waluigi
  -wr = Wario
  -ys = Yoshi
  ```

So `lb_kart-fk.szs` = **Flame Flyer, ridden by Funky Kong**



##### Download kart (`.szs`) mod

[mkwiiki.org](https://mkwiiki.org/wiki/Category:Vehicle/Custom)

[gamebanana.com](https://gamebanana.com/mods/cats/10108)





##### Load a kart (`.szs`) mod

Kart model files live in `extracted/DATA/files/Race/Kart/`. WiiCompiled's binary contains baked **code** only — kart, track and other assets are read from `dvd_root` while the game runs, so replacing a file in `extracted/DATA/files/` takes effect on the next launch: **no recompile is needed**, and the Retro Rewind pack's `MyStuff/` folder is *not* read by WiiCompiled (it is a Riivolution/Dolphin convention).

```shell
$ cd Wiicompiled-linux
$ KART=extracted/DATA/files/Race/Kart
$ mkdir -p "$KART/_originals"
$ F=lb_kart-fk.szs                          # the file(s) shipped by the mod
$ cp -a "$KART/$F" "$KART/_originals/$F"   # back up the original
$ cp -a /path/to/mod/"$F" "$KART/$F"       # drop the modded file in place
$ sha256sum /path/to/mod/"$F" "$KART/$F"   # verify byte-identical
```

Then launch `./linux-native-build/RetroRewind` (or `WiiCompiled`) and **start a race** with the matching character and vehicle — the model is loaded into the race scene, so it is not visible on the title screen or character select.

> [!TIP]
>
> mods are usually packed with a `Race/Kart/` folder (or with a readme naming the target files) because that is where the game loads them from. If the pack ships the files flat, copy them so they keep their exact `<vehicle>-<character>.szs` names — WiiCompiled has no My Stuff fallback, so only *exact* game-file names override anything.

> [!TIP]
>
> each kart file also has `_4` variants (e.g. `lb_kart-fk_4.szs`) used by **multiplayer/online** races, while the base file is used in offline races. Most packs only ship the base files — the model will be stock in online races (and possibly in 2P+ split-screen) until the `_4` variants are also replaced.

To revert, restore the backups:

```shell
$ for f in "$KART"/_originals/*; do cp -a "$f" "$KART/$(basename "$f")"; done
```
