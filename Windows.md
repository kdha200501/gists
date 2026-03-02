# SSH

##### Network address

By default, WSL2 uses a NAT-based virtual network, which gives WSL an IP address that's inaccessible by other machine in the LAN.

Mirroring the host machine's network allows other machines on the LAN to reach WSL services (like `sshd`) using the host machine's IP address.



```powershell
Add-Content "$env:USERPROFILE\.wslconfig" "`n[wsl2]`nnetworkingMode=mirrored"
wsl --shutdown
wsl
```

> [!NOTE]
>
> Requires WSL version 2.0.0 or later (`wsl --version`).





##### Reverse tunnelling

If the machine is so locked down that it won't allow installing `opensshd`, then use reverse tunnelling

In WSL

> [!TIP]
>
> No one wants to use the Windows shells, so let's dig a tunnel from WSL

```shell
$ ssh -R 2222:localhost:22 <username>@<ip-address>
```

In the other machine

```shell
$ ssh <username>@localhost -p 2222
```

