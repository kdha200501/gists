There is an official build of the AWS VPN client, but it's packaged in `.deb` only.

The build is packaged for Fedora via copr, ref: [link](https://copr.fedorainfracloud.org/coprs/vorona/aws-rpm-packages/)



```shell
$ sudo dnf copr enable vorona/aws-rpm-packages
$ sudo dnf install awsvpnclient -y
$ sudo systemctl start aws-client-vpn-daemon
```

