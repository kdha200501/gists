There is an official build of the AWS VPN client, but it's packaged in `.deb` only.

The build is packaged for Fedora via copr, ref: [link](https://copr.fedorainfracloud.org/coprs/vorona/aws-rpm-packages/)



```shell
$ sudo dnf copr enable vorona/aws-rpm-packages
$ dnf install awsvpnclient -y
$ systemctl start awsvpnclient
```

