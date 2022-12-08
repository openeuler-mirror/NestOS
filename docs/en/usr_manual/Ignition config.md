# Ignition Config Description

## User and group configuration

Use the following configuration files to create nest users and configure passwords (hash values), groups, and SSH keys

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

## File Management Configuration

Use the following configuration：

1. Create the /opt/tools folder.

2. Create file /var/helloworld and set permissions, owning users, and owning groups for the file

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

## Storage configuration

Use the following configuration files to change the root file system to ext4

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

## Kernel parameter configuration

Use the following configuration file to disable sysrq

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

## Host Name Configuration

Use the following configuration file to set the hostname and write /etc/hostname

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

## Time Zone Configuration

By default, NestOS machines keep the time in UTC and synchronize their clocks with the Network Time Protocol (NTP).

You can use the following configuration file to set your required time zone

```
variant: fcos
version: 1.1.0
storage:
  links:
    - path: /etc/localtime
      target: ../usr/share/zoneinfo/America/New_York
```

## Network configuration

Configure the static IP for NIC ens33 with the following configuration file

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

## Container configuration

Use the following configuration file to start the system, start the docker service, pull the busybox image, and run the busybox container

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

