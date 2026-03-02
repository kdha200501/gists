# SSH

##### Network address

By default, WSL2 uses a NAT-based virtual network, which gives WSL an IP address that's inaccessible by other machine in the LAN.

Mirroring the host machine's network allows other machines on the LAN to reach WSL services (like `sshd`) using the host machine's IP address.



```powershell
$ Add-Content "$env:USERPROFILE\.wslconfig" "`n[wsl2]`nnetworkingMode=mirrored"
$ wsl --shutdown
$ wsl
```

> [!NOTE]
>
> Requires WSL version 2.0.0 or later (`wsl --version`).





##### Reverse tunnelling

If the machine is so locked down that it won't allow installing `opensshd`, then use reverse tunnelling in WSL

> [!TIP]
>
> No one wants to use the Windows shells anyways, so let's dig a tunnel from WSL



Install, start and enable `sshd`

```shell
$ sudo dnf install openssh-server
$ sudo systemctl start sshd
$ sudo systemctl enable sshd

$ vim ~/.ssh/config
```

Copy and paste:

```shell
Host <ip-address>
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
```

> [!NOTE]
>
> where `ip-address` is the IP address of the other machine



Open a tunnel

```shell
$ ssh -R 2222:localhost:22 <username>@<ip-address>
```

> [!NOTE]
>
> where `ip-address` is the IP address of the other machine



In the other machine, configure and connect to the tunnel

```shell
$ vim ~/.ssh/config
```

Copy and paste:

```
Host localhost
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
```



```shell
$ ssh <username>@localhost -p 2222
```






##### Using the Windows host's git in WSL

To avoid installing git in WSL, shim it to the Windows `git.exe` via interop

```shell
$ cat > ~/.local/bin/git <<'SH'
#!/bin/bash
exec "/mnt/c/Users/<username>/AppData/Local/Programs/Git/cmd/git.exe" "$@"
SH
$ chmod +x ~/.local/bin/git
```

> [!WARNING]
>
> `~/.local/bin` is not on root's `PATH` (`$HOME` is `/root` under `sudo`), so scripts run with `sudo` report `git: command not found`. Either run the script without `sudo` or also install the shim system-wide
>
> ```shell
> $ sudo cp ~/.local/bin/git /usr/local/bin/git
> ```

> [!WARNING]
>
> Windows git sees WSL repos as UNC paths (`//wsl.localhost/...`) and rejects them with `detected dubious ownership`, which makes commands like `git remote get-url` fail silently. Trust them with
>
> ```shell
> $ git config --global --add safe.directory '*'
> ```





##### Using the Windows host's node, npm and npx in WSL

Alias them to the Windows executables (e.g. the ones managed by nvm-windows) in `~/.bashrc`

```shell
# Windows cli tools via WSL interop
alias node="'/mnt/c/Users/<username>/AppData/Local/Author Software/nvm/.nodejs/node.exe'"
alias npm="'/mnt/c/Users/<username>/AppData/Local/Author Software/nvm/.nodejs/npm.exe'"
alias npx="'/mnt/c/Users/<username>/AppData/Local/Author Software/nvm/.nodejs/npx.exe'"
```

> [!NOTE]
>
> Aliases only apply to interactive shells, so scripts and `sudo` won't see them. Use executable shims on `PATH` (like the git one above) for those cases.
