# Quick Start

## Deploy NestOS on VMware

This guide shows how to configure the latest NestOS on VMware.

Currently, NestOS supports both x86_64 and aarch64 architectures.

### Before the start

Prepare:

- Download the NestOS ISO
- Prepare the config.bu
- Configure the butane (Linux / win10)
- Install

### Initial installation and startup

![image-20211014200951942](/docs/en/graph/QuickStart/image-20211014200951942.png)

#### Start NestOS

The initial startup of NestOS is shown as follow：

![image-20211014201036415](/docs/en/graph/QuickStart/image-20211014201036415.png)

When start nestos for the first time, the ignition is not installed. So you can install it using the Nestos-Installer component.

![image-20211014201046509](/docs/en/graph/QuickStart/image-20211014201046509.png)

### Configure ignition

#### Get Butane

Bu files can be converted to igniton files via Butane. The ignition file is designed to be readable but hard to write, to discourage users from trying to write a configuration manually. Butane provides support for a variety of environments and can be configured in a linux/windows host or container environment.

```
docker pull hub.oepkgs.net/nestos/butane:0.14.0
```

#### Generate the login password

Run the following command on the host and enter the password.

```
# openssl passwd -1 -salt yoursalt
Password:
$1$yoursalt$1QskegeyhtMG2tdh0ldQN0
```

#### Generate ssh-key

Run the following command on the host to obtain the public key and private key for ssh login.

```
# ssh-keygen -N '' -f ./id_rsa
Generating public/private rsa key pair.
Your identification has been saved in ./id_rsa
Your public key has been saved in ./id_rsa.pub
The key fingerprint is:
SHA256:4fFpDDyGHOYEd2fPaprKvvqst3T1xBQuk3mbdon+0Xs root@host-12-0-0-141
```

```
The key's randomart image is:
+---[RSA 3072]----+
|   ..= . o .   |
|    * = o * .  |
|     + B = *   |
|     o B O + . |
|      S O B o  |
|       * = . . |
|      . +o . . |
|     +.o . .E  |
|    o*Oo   ... |
+----[SHA256]-----+
```

view the id_rsa.pub public key

```
# cat id_rsa.pub
ssh-rsa
AAAAB3NzaC1yc2EAAAADAQABAAABgQDjf+I9QQZ+3vNWomqxpHkZq7ONHcEYBzs4C9RZahmLYVPBf/3y
HF5wTtfl5CBviERUnLGFn8c4Ua9MNWcJL6zE01xXtDZ2db7vaPwP3Qbo1lKJg1BVw6u+5bMKCJxEnN9+
aOiX3A2XpkUVxhCoGlei3j78oLRU3ucCLn6m7wVE+P53tNQ5364xWqbAsDXdze4xnNZjlzH9JvjJ5IJY
WjwrD7UUkfI8qDj5ub9Gz+nSenaaSboWADsKe4JTLoU2Gz5fPLCj+uuNFpZAUc/GCe47He5UO6IbHjDI
bxqhzYZQTXdwIgKIM1PL19IkAAY07gU53b4gDSDj7SZYB+jjtgG8VoFF4m7nCJgRDeUKGTNT5fsLPKAZ
tmBvy9Mg5qkK/LisEzjUwPPh1NEb8bgN251wPXmPMjQ1aMzD8t9blq40KEyod2Eg05nW2q5/90ICNQBa
r9AkQrQ/3j8WsejvqseWIi1kq68pqvtcBJkCMiIfzIoUgCgcolw3fZprDhgfau8= root@host-12-0-
0-141
```

#### Prepare the bu file

Start with the simplest initial configuration, but for more details, see ignition below. The following is the simplest config.bu file

```
variant: nestos
version: 1.1.0
passwd:
  users:
    - name: core
      password_hash: "$1$yoursalt$1QskegeyhtMG2tdh0ldQN0"
      ssh_authorized_keys:
        - "ssh-rsa
  AAAAB3NzaC1yc2EAAAADAQABAAABgQDjf+I9QQZ+3vNWomqxpHkZq7ONHcEYBzs4C9RZahmLYVPBf/3y
  HF5wTtfl5CBviERUnLGFn8c4Ua9MNWcJL6zE01xXtDZ2db7vaPwP3Qbo1lKJg1BVw6u+5bMKCJxEnN9+
  aOiX3A2XpkUVxhCoGlei3j78oLRU3ucCLn6m7wVE+P53tNQ5364xWqbAsDXdze4xnNZjlzH9JvjJ5IJY
  WjwrD7UUkfI8qDj5ub9Gz+nSenaaSboWADsKe4JTLoU2Gz5fPLCj+uuNFpZAUc/GCe47He5UO6IbHjDI
  bxqhzYZQTXdwIgKIM1PL19IkAAY07gU53b4gDSDj7SZYB+jjtgG8VoFF4m7nCJgRDeUKGTNT5fsLPKAZ
  tmBvy9Mg5qkK/LisEzjUwPPh1NEb8bgN251wPXmPMjQ1aMzD8t9blq40KEyod2Eg05nW2q5/90ICNQBa
  r9AkQrQ/3j8WsejvqseWIi1kq68pqvtcBJkCMiIfzIoUgCgcolw3fZprDhgfau8= root@host-12-0-
  0-141"
```

#### Generate the ignition file

Convert config.bu to the config.ign using the Butane tool.

```
# docker run --interactive --rm hub.oepkgs.net/nestos/butane:0.14.0 \
--pretty --strict < your_config.bu > transpiled_config.ign
```

Conversion can also be performed in other environments. Butane offers a variety of ways to convert, which can be viewed at the following address.
https://github.com/coreos/butane

### Install NestOS

Copy the config.ign file to the NestOS, which is currently running in memory, not installed on the hard disk.

```
sudo -i
# Please change the ip of the machine on which your ign files are generated
scp root@10.1.110.88:/root/config.ign /root            
```

Perform the following operations as prompted to complete the installation.

```
nestos-installer install /dev/sda --ignition-file config.ign
```

Restart NestOS after installed.

```
systemctl reboot
```

