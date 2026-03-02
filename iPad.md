# Secure Shell

RHEL system's crypto policy blocks SHA1 RSA signatures (which OpenSSH 6.7 uses). Set `OPENSSL_CONF=/dev/null` bypasses the policy.



##### ssh

```shell
$ OPENSSL_CONF=/dev/null ssh -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no root@<ip-address>
```



##### scp

```shell
$ OPENSSL_CONF=/dev/null scp -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o StrictHostKeyChecking=no <path-to-source> root@<ip-address>:<path-to-destination>
```

