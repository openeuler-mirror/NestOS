# 基于OpenStack部署NestOS

本指南展示了如何在OpenStack平台上部署NestOS。

目前NestOS支持x86_64和aarch64两种架构。

### 开始之前

​		在开始部署 NestOS 之前,需要做如下准备工作:

- 下载 NestOS OpenStack qcow2
- 准备 config.bu 文件
- 配置 butane 工具(Linux环境/win10环境)
- OpenStack平台

### 配置 ignition 文件

#### 获取 Butane

可以通过 Butane 将 bu 文件转化为 igniton 文件。ignition 配置文件被设计为可读但难以编写，是为了
阻止用户尝试手动编写配置。
Butane 提供了多种环境的支持，可以在 linux/windows 宿主机中或容器环境中进行配置。

```
docker pull hub.oepkgs.net/nestos/butane:0.14.0
```

#### 生成登录密码

在宿主机执行如下命令，并输入你的密码。

```
# openssl passwd -1 -salt yoursalt
Password:
$1$yoursalt$1QskegeyhtMG2tdh0ldQN0
```

#### 生成ssh-key

在宿主机执行如下命令，获取公钥和私钥以供后续 ssh 登录。

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

可以在当前目录查看id_rsa.pub公钥

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

#### 编写bu文件

进行最简单的初始配置，如需更多详细的配置，参考后面的 ignition 详解。
如下为最简单的 config.bu 文件

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

#### 生成ignition文件

将 config.bu 通过 Butane 工具转换为 config.ign 文件，如下为在容器环境下进行转换。

```
# docker run --interactive --rm hub.oepkgs.net/nestos/butane:0.14.0 \
--pretty --strict < your_config.bu > config.ign
```

也可在其他环境下进行转换，Butane提供了多种转换的方式,可在如下地址查看。
https://github.com/coreos/butane

### 安装部署 NestOS

在OpenStack平台上上传 NestOS OpenStack qcow2镜像

```
openstack image create --disk-format=qcow2 --min-disk=10 --min-ram=2 --file=nestos nestos-XX.XXXXXXXX.X.X-openstack.x86_64.qcow2
```

镜像上传成功后，启动NestOS实例

```
openstack server create            \
     --key-name=mykeypair          \
     --network=private             \
     --flavor=v1-standard-2        \
     --image=nestos                \
     --user-data config.ign.ign    \
     nestos-openstack
```
命令执行成功可成功部署NestOS实例