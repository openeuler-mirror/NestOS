# ign文件说明

## 用户和组配置

使用如下配置文件来创建nest用户并配置密码（hash值）、组和SSH密钥

```
variant: fcos
version: 1.1.0
passwd:
  users:
    - name: nest
      # Password is qwer1234!@#$
      password_hash: "$1$yoursalt$UGhjCXAJKpWWpeN8xsF.c/"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      # SSH key for the local user.
      ssh_authorized_keys:
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCsgIP2uIynA2cUSRwaHpE7VV8enHhIv/Npp/wESgOyImkTH7ye89Al1Wo00hpxiIZqN6rKxj/DCL4HraM76uJ6nTJTdRs/XzVyNa5jfOe1YDmHnn3MN6cOUqn48v2+JU0o3eIaL7w72s9KOuk+NwrePyQd2BEhJiKDqOAiU/lf5xw+bpfxk8G8FzYWqtF7vGyVMw8Jlo+jQbPoc5ImO4yQ8tC7klwqPJ4v26Fz4ihUFXZk10+o2qVdtkaLOfA8MNbHXU1PTx6fqIPC+Vhd5n8X4WfgcdYIFmoovEg8lhpqCB3TIzZI7eSU4hSEEas3pVVCi58pQBAt5xSfF/Shr0+qGEGyub9rgweMm/Avv5s3CIEhWUDgwUZ5sfRUiLqN2Hil8ugsNmAUIqGLa536yNTYFUTGQHimq2qchrETIX3xD5emcWORQikaxdXixq/tDbAgr4q+M9zAMy0CzIDbUCi+2DDIjr9tL/r9KiZYpQUAai8yCkJb6g3Ct2pMsqnQdEk= root" 
```

## 文件管理配置

使用如下配置文件来实现：

1.创建文件夹/opt/tools；

2.创建文件/var/helloworld并设置文件权限、所属用户和组

```
variant: fcos
version: 1.1.0
passwd:
  users:
    - name: nest
      password_hash: "$1$yoursalt$UGhjCXAJKpWWpeN8xsF.c/"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      # Public key 
      ssh_authorized_keys:
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCsgIP2uIynA2cUSRwaHpE7VV8enHhIv/Npp/wESgOyImkTH7ye89Al1Wo00hpxiIZqN6rKxj/DCL4HraM76uJ6nTJTdRs/XzVyNa5jfOe1YDmHnn3MN6cOUqn48v2+JU0o3eIaL7w72s9KOuk+NwrePyQd2BEhJiKDqOAiU/lf5xw+bpfxk8G8FzYWqtF7vGyVMw8Jlo+jQbPoc5ImO4yQ8tC7klwqPJ4v26Fz4ihUFXZk10+o2qVdtkaLOfA8MNbHXU1PTx6fqIPC+Vhd5n8X4WfgcdYIFmoovEg8lhpqCB3TIzZI7eSU4hSEEas3pVVCi58pQBAt5xSfF/Shr0+qGEGyub9rgweMm/Avv5s3CIEhWUDgwUZ5sfRUiLqN2Hil8ugsNmAUIqGLa536yNTYFUTGQHimq2qchrETIX3xD5emcWORQikaxdXixq/tDbAgr4q+M9zAMy0CzIDbUCi+2DDIjr9tL/r9KiZYpQUAai8yCkJb6g3Ct2pMsqnQdEk= root
storage:
  # This creates a directory. Its mode is set to 0755 by default
  directories:
  - path: /opt/tools
    overwrite: true
  files:
    -
      # Creates a file /var/helloworld containing a string defined in-line
      path: /var/helloworld
      overwrite: true
      contents:
        inline: Hello, world!
      # Sets the file mode to 0644 (readable by all, writable by the owner).
      mode: 0644
      # Sets owernship to dnsmasq:dnsmasq.
      user:
        name: nest
      group:
        name: engineering
```

## 存储配置

使用如下配置文件来改变root文件系统为ext4格式

```
variant: fcos
version: 1.1.0
storage:
  filesystems:
    - device: /dev/disk/by-partlabel/root
      wipe_filesystem: true
      format: ext4
      label: root
```

## 内核参数配置

使用如下配置文件来禁用sysrq

```
variant: fcos
version: 1.1.0
storage:
  files:
    - path: /etc/sysctl.d/90-sysrq.conf
      contents:
        inline: |
          kernel.sysrq = 0
```

## 主机名配置

使用如下配置文件来将您需要设置的主机名写入/etc/hostname

```
variant: fcos
version: 1.1.0
storage:
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: nestoshost
```

## 时区配置

默认情况下，NestOS机器将时间保持在UTC，并将其时钟与网络时间协议 (NTP) 同步。

可以通过如下配置文件设置您所需的时区

```
variant: fcos
version: 1.1.0
storage:
  links:
    - path: /etc/localtime
      target: ../usr/share/zoneinfo/America/New_York
```

## 网络配置

通过如下配置文件为网卡ens33配置静态IP

```
variant: fcos
version: 1.1.0
storage:
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: nestoshost
    
    - path: /etc/NetworkManager/system-connections/ens33.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=ens33
          type=ethernet
          interface-name=ens33
          [ipv4]
          address1=192.168.237.188/24,192.168.237.2
          dns=8.8.8.8;
          dns-search=
          method=manual
```

## 容器配置

使用如下配置文件使系统启动后，开启docker服务，并录取busybox镜像，运行busybox容器

```
variant: fcos
version: 1.1.0
systemd:
  units:
    - name: hello.service
      enabled: true
      contents: |
        [Unit]
        Description=MyApp
        After=network-online.target
        Wants=network-online.target

        [Service]
        TimeoutStartSec=0
        ExecStartPre=systemctl start docker
        ExecStartPre=/bin/docker pull busybox
        ExecStart=/bin/docker run --name busybox1 busybox /bin/sh -c "trap 'exit 0' INT TERM; while true; do echo Hello World; sleep 1; done"

        [Install]
        WantedBy=multi-user.target       
```

