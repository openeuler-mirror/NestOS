# Deploying NestOS based on OpenStack

This guide shows how to deploy NestOS on the OpenStack platform.

Currently, NestOS supports x86_ 64 and aarch64 architectures.

### Before starting

Before starting to deploy NestOS, the following preparations need to be made:

- download NestOS OpenStack qcow2
- Prepare the config.bu file
- Configure Butane Tool(Linux environment/win10 environment)
- OpenStack Platform

### Configure the ignition file

#### Get Butane

You can convert bu files into igniton files through Butane。The ignition configuration file is designed to be readable but difficult to write，It is to prevent users from attempting to manually write configurations。
Butane provides support for multiple environments，It can be configured in a Linux/Windows host or container environment。

```
docker pull hub.oepkgs.net/nestos/butane:0.14.0
```

#### Generate login password

Execute the following command on the host and enter your password.

```
# openssl passwd -1 -salt yoursalt
Password:
$1$yoursalt$1QskegeyhtMG2tdh0ldQN0
```

#### Generate ssh key

Execute the following command on the host to obtain the public and private keys for subsequent SSH login.

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

You can view the ID in the current directory_ Rsa.pub public key

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

#### Write bu file

Perform the simplest initial configuration，For more detailed configurations, please refer to the subsequent IGNATION explanation。The following is the simplest config.bu file

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

#### Generate ignition file

Convert config.bu to config.ign file through the Butane tool，The following is a conversion in a container environment.

```
# docker run --interactive --rm hub.oepkgs.net/nestos/butane:0.14.0 \
--pretty --strict < your_config.bu > config.ign
```

It can also be converted in other environments, and Butane provides multiple conversion methods, which can be viewed at the following address。https://github.com/coreos/butane

### Install and deploy NestOS

Upload NestOS OpenStack qcow2 image on the OpenStack platform

```
openstack image create --disk-format=qcow2 --min-disk=10 --min-ram=2 --file=nestos nestos-XX.XXXXXXXX.X.X-openstack.x86_64.qcow2
```

After successfully uploading the image, start the NestOS instance

```
openstack server create            \
     --key-name=mykeypair          \
     --network=private             \
     --flavor=v1-standard-2        \
     --image=nestos                \
     --user-data config.ign.ign    \
     nestos-openstack
```
Successful command execution can successfully deploy NestOS instance