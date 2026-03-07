# SSH

##### Enable password for sshd

```shell
$ nano /boot/system/settings/ssh/sshd_config
```

Edit to enable

```
PermitRootLogin yes
PasswordAuthentication yes
```

> [!NOTE]
>
> run `whoami` to get username
>
> run `passwd` to set password

















# Power cycle

##### Shutdown

```shell
$ shutdown
```



##### Reboot

```shell
$ shutdown -r
```

















# Package manager

##### Update OS

```shell
$ pkgman refresh
$ pkgman full-sync
```





##### Install node and npm

```shell
$ pkgman install vim_x86
$ pkgman install nodejs20_x86
```



```shell
$ pkgman install curl-x86
$ ln -s /boot/system/bin/curl-x86 /boot/home/config/non-packaged/bin/curl

# 1. Create the necessary directories in your writable home
mkdir -p /boot/home/config/non-packaged/lib/node_modules
mkdir -p /boot/home/config/non-packaged/bin

# 2. Go to your downloads folder
cd ~/Downloads

# 3. Download the npm tarball (using the curl alias we made)
curl -L https://registry.npmjs.org/npm/-/npm-10.9.0.tgz -o npm.tgz

# 4. Extract it directly into your non-packaged node_modules
tar -xzf npm.tgz -C /boot/home/config/non-packaged/lib/node_modules/

# 5. The extraction creates a folder named 'package'. Rename it to 'npm'
mv /boot/home/config/non-packaged/lib/node_modules/package /boot/home/config/non-packaged/lib/node_modules/npm

# 6. Create the symlink so the 'npm' command works
ln -s /boot/home/config/non-packaged/lib/node_modules/npm/bin/npm-cli.js /boot/home/config/non-packaged/bin/npm

# 7. Make sure the script is executable
chmod +x /boot/home/config/non-packaged/lib/node_modules/npm/bin/npm-cli.js
```



```shell
$ mkdir -p /boot/home/config/non-packaged/bin/npm-global
$ npm config set prefix '/boot/home/config/non-packaged/bin/npm-global'

$ vim /boot/home/config/settings/profile
```

Append

```shell
export PATH="$PATH:/boot/home/config/non-packaged/bin/npm-global/bin"
```





##### Install git

```shell
$ pkgman install git_x86
$ ln -s /boot/system/bin/git-x86 /boot/home/config/non-packaged/bin/git

git config --global user.name "Your Name"
git config --global user.email "youremail@example.com"
```

