# 基于NestOS容器化部署OpenStack

## 一、整体方案

本指南旨在提供NestOS容器化部署OpenStack的解决方案。

本指南以虚拟化平台创建多个NestOS实例作为部署OpenStack验证环境，裸金属场景也可参照本文并结合NestOS裸金属安装文档完成OpenStack部署。

验证环境参考如下：

-   部署环境基本信息
    -   部署节点OS：openEuler 21.09
    -   OpenStack版本：Wallaby
    -   Kolla-ansible版本：12.0.0

-   实例配置
    -   NestOS版本：nestos-22.03.20220329-qemu.x86_64.qcow2
    -   内核版本：5.10.0-52.0.0.26.oe2203.x86_64
    -   网卡*2

-   部署环境资源架构说明
    -   表格中CPU、内存以及硬盘容量为最低要求。
    -   网卡2专用于Neutron外部（或公共）网络，可以是vlan或flat，取决于网络的创建方式。此网卡应该在没有IP地址的情况下处于活动状态。否则，实例将无法访问外部网络。
    -   存储节点如采用本地存储方案（如LVM）可添加第二块硬盘。

| 用途                         | 主机名    | 网卡1           | 网卡2    | CPU  | 内存 | 硬盘1 | 硬盘2 |
| ---------------------------- | --------- | --------------- | -------- | ---- | ---- | ----- | ----- |
| 部署节点                     | localhost | IP              |          |      |      |       |       |
| 控制节点、网络节点、监控节点 | nestos01  | NESTOS_NODE1_IP | 无需配置 | 4C   | 8G   | 40G   |       |
| 计算节点、存储节点           | nestos02  | NESTOS_NODE2_IP | 无需配置 | 4C   | 8G   | 40G   | 40G   |

## 二、NestOS实例创建与配置

NestOS通过ignition点火文件机制实现节点批量配置。本章节简要介绍ignition点火文件生成方法，并提供容器化部署OpenStack时点火文件配置参考。

本指南以libvirt方式创建NestOS实例，并给出相应步骤和命令供参考，其他部署方式可参考NestOS安装部署文档。

**注意：** 采用其他部署方式时ignition点火文件可能需要进行相应调整。

### 2.1 生成ignition点火配置文件

容器化部署OpenStack时，NestOS节点所需ignition点火配置分为系统配置与OpenStack部署环境初始化两部分，主要配置内容如下：

| 类别                    | 配置项                                           | 用途                                   |
| ----------------------- | ------------------------------------------------ | -------------------------------------- |
| 系统配置                | passwd                                           | 配置NestOS登录用户和访问鉴权等相关信息 |
| 主机名                  | 配置NestOS实例主机名                             |                                        |
| 网卡1                   | 该网卡负责部署、运维NestOS实例，提供基础网络环境 |                                        |
| 时区                    | 配置NestOS实例默认时区，否则无/etc/localtime文件 |                                        |
| OpenStack部署环境初始化 | 内核参数                                         | OpenStack部署环境需开启部分内核参数    |
| 网卡2                   | 该网卡专用于 Neutron使用                         |                                        |
| 安装python环境          | OpenStack部署环境需python环境                    |                                        |
| 关闭selinux             | OpenStack部署环境需关闭selinux                   |                                        |
| 设置时间同步            | OpenStack部署环境需通过chronyd服务同步集群时间   |                                        |
| 存储配置                | 供OpenStack集群使用，存储节点必选                |                                        |

具体操作步骤如下：

#### 2.1.1 准备Butane

Butane可以将bu文件转化为ignition文件。现阶段可采用下述命令拉取Butane容器镜像使用，后续将会支持openEuler软件源安装使用。

```bash
docker pull quay.io/coreos/butane:latest
```

#### 2.1.2 生成登录密码

如计划使用密码登录方式访问NestOS实例，可使用下述命令生成 **${PASSWORD_HASH}** 供后文点火文件配置使用。

```bash
openssl passwd -1 -salt yoursalt
```

#### 2.1.3 生成 ssh密钥对

如计划采用ssh公钥方式访问NestOS实例，可通过下述命令生成ssh密钥对（以生成路径为/root/.ssh/为例；若已有密钥对，可跳过此步）：

```bash
ssh-keygen -N '' -f /root/.ssh/id_rsa
```

查看公钥文件id_rsa.pub，获取ssh公钥信息 **${SSH-RSA}** 供后文点火文件配置使用。

```bash
cat /root/.ssh/id_rsa.pub
```

#### 2.1.4 编写bu配置文件

生成供NestOS使用的ignition前需手动编写bu配置文件，详情请查阅NestOS官方文档。

本指南创建名为nestos_config.bu的bu配置文件，示例如下，用于创建计划部署OpenStack集群的NestOS实例，供参考。

**警告：** 使用本配置文件示例，将会关闭selinux。

**注意：** 本配置文件示例中，形如 **${VALUE}** 字段均需根据实际部署情况自行配置。部分字段上文提供了生成方法。

```yaml
variant: fcos
version: 1.1.0
## passwd相关配置
passwd:
  users:
    - name: nest
      ## 登录密码
      password_hash: "${PASSWORD_HASH}"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      ## ssh公钥信息
      ssh_authorized_keys:
        - "${SSH-RSA}"
storage:
  files:
    ## 主机名
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: ${HOSTNAME}
    ## 内核参数配置-part1
    - path: /etc/sysctl.conf
      mode: 0644
      overwrite: true
      contents:
        inline: |
          net.ipv4.ip_forward = 1
          net.bridge.bridge-nf-call-iptables=1
          net.bridge.bridge-nf-call-ip6tables=1
          net.ipv4.ip_nonlocal_bind = 1
          net.ipv6.ip_nonlocal_bind=1
          net.unix.max_dgram_qlen=128
      ## 网卡1，以ens2为例，如节点较多可配置为DHCP方式
    - path: /etc/NetworkManager/system-connections/${ens2}.nmconnection
      mode: 0600
      overwrite: true
      contents:
        inline: |
          [connection]
          id=${ens2}
          type=ethernet
          interface-name=${ens2}
          [ipv4]
          address1=${YOUR_IP}/24,${YOUR_GATEWAY}
          dns=${YOUR_DNS};
          dns-search=
          method=manual
    ## 网卡2，以ens3为例
    - path: /etc/NetworkManager/system-connections/${ens3}.nmconnection
      mode: 0600
      contents:
        inline: |
          [connection]
          id=${ens3}
          type=ethernet
          interface-name=${ens3}
          ## The second network interface should be active without IP address. 
          [ipv4]
          dns-search=
          method=disabled
  links:
    ## 时区
    - path: /etc/localtime
      ## 以上海时区为例 target: ../usr/share/zoneinfo/Asia/Shanghai
      target: ${YOUR_ZONEINFO_PATH}
systemd:
  units:
    ## 安装python环境
    - name: install-python3-for-openstack.service
      enabled: true
      contents: |
        [Unit]
        Description=install python3 for openstack
        Wants=network-online.target
        After=network-online.target
        Before=zincati.service
        ConditionPathExists=!/var/lib/install-python3-for-openstack.stamp
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/usr/bin/rpm-ostree install --apply-live python3-devel python3-docker python3-libselinux
        ExecStart=/bin/touch /var/lib/install-python3-for-openstack.stamp
        [Install]
        WantedBy=multi-user.target
    ## 关闭selinux
    - name: disable-selinux-for-openstack.service
      enabled: true
      contents: |
        [Unit]
        Description=disable selinux for openstack
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config"
        ExecStart=setenforce 0
        [Install]
        WantedBy=multi-user.target
    ## 内核参数配置-part2
    - name: set-kernel-para-for-openstack.service
      enabled: true
      contents: |
        [Unit]
        Description= for openstack
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=modprobe br_netfilter
        ExecStart=sysctl -p
        [Install]
        WantedBy=multi-user.target
    ## 设置时间同步
    - name: set-time-synch-for-openstack.service
      enabled: true
      contents: |
        [Unit]
        Description=set time synchronization for openstack
        Wants=chronyd.service
        After=chronyd.service
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "sed -i '1a server ${localhost_ip} iburst' /etc/chrony.conf"
        ExecStart=systemctl restart chronyd.service
        ExecStart=systemctl enable chronyd.service
        [Install]
        WantedBy=multi-user.target
     ## 存储配置，以LVM为例
     ## TODO
```

#### 2.1.5 生成ignition文件

配置编写完毕后，将上述nestos_config.bu通过Butane工具转换为nestos_config.ign点火文件，下述为通过Butane容器环境进行转换命令。

```bash
docker run --interactive --rm quay.io/coreos/butane:latest --pretty --strict < nestos_config.bu > nestos_config.ign
```

### 2.2 创建NestOS实例

本指南以libvirt方式创建NestOS实例，以下为参考步骤。如采用其他方式安装部署NestOS，请参阅NestOS安装部署文档并使用2.1生成的点火配置文件完成配置。

**注意：** 本配置文件示例中，形如 **${VALUE}** 字段均需根据实际部署情况自行配置。

#### 2.2.1 创建独立网络

因OpenStack部署需要NestOS实例拥有两块网卡，且最终网络不得为同一子网，本指南计划两块网卡分别接入不同网络，故需创建独立网络。如计划采用VLAN等形式，可跳过此步。

libvirt宿主机创建名为virbr1.xml的配置文件，填写内容如下：

```bash
<network>
  <name>virbr1</name>
  <bridge name="virbr1"/>
  <forward mode="nat"/>
  <ip address="${BRIDGE_IP}" netmask="255.255.255.0">
    <dhcp>
      <range start="${DHCP_IPPOOL_START}" end="${DHCP_IPPOOL_END}"/>
    </dhcp>
  </ip>
</network>
```

libvirt宿主机执行下述命令，创建新的网络virbr1：

```bash
virsh net-create --file virbr1.xml
```

#### 2.2.2 libvirt创建NestOS实例

在libvirt宿主机执行下述命令创建NestOS虚拟机，其中vcpus、ram和disk参数均为最低要求，可自行调整，请参考virt-install手册。

```bash
virt-install --name=${NAME} --vcpus=4 --ram=8192 --import --network=bridge=virbr0 --graphics=none --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${ignition_FILE_PATH}" --disk=size=40,backing_store=${NESTOS_RELEASE_QCOW2_PATH} --network=bridge=virbr1 --disk=size=40
```

## 三、OpenStack配置

OpenStack容器化部署主流采用Kolla-ansible方案，基于NestOS部署同样采用该方案。本章节配置步骤为Kolla-ansible方案部署一般配置步骤，与NestOS无直接关联。

本章节提供配置方案仅供参考，寻求更详细信息请查阅OpenStack官方部署文档。

### 3.1 部署节点

部署节点可为任意可访问NestOS实例的Linux节点，因NestOS基于openEuler生态构建，强烈建议部署节点采用openEuler操作系统，以便Kolla-ansible相关软件包版本一致，防止因版本差异产生异常。

在本指南验证环境中，部署节点主机名为localhost，操作系统为openEuler 21.09。

#### 3.1.1 免密登录NestOS实例

**注意：** 本配置文件示例中，形如 **${VALUE}** 字段均需根据实际部署情况自行配置。

在/etc/hosts中添加NestOS实例信息，以便通过主机名连接。

```bash
## /etc/hosts结尾追加
${NESTOS_NODE1_IP} nestos01
${NESTOS_NODE2_IP} nestos02
```

确认部署节点可通过主机名以SSH方式正常访问NestOS实例。

```bash
## 如点火文件已配置SSH公钥，以下步骤可跳过
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub ${nest}@nestos01
ssh-copy-id -i ~/.ssh/id_rsa.pub ${nest}@nestos02

## 测试可正常访问
ssh nest@nestos01
ssh nest@nestos02
```

#### 3.1.2 安装Kolla Ansible

```bash
yum install -y openstack-kolla openstack-kolla-ansible
```

#### 3.1.3 配置 Ansible

将以下选项添加到Ansible配置文件/etc/ansible/ansible.cfg中。

```bash
[defaults]
host_key_checking=False
pipelining=True
forks=100
```

#### 3.1.4 配置清单文件

清单是一个Ansible文件，可以在其中指定主机及其所属的组，主要使用它来定义节点角色和访问凭证。

Kolla Ansible中默认的清单文件包含两类，分别是all-in-one和multinode，两者的区别在于前者是在localhost上部署单节点OpenStack，如使用单独的主机或者使用多个节点，则需选择multinode清单文件。

本方案选用multinode清单文件，下述配置信息仅供参考，详细使用请查询OpenStack官方文档。

**注意：** 本配置文件示例中，形如 **${VALUE}** 字段均需根据实际部署情况自行配置。

**提示：** 如NestOS节点配置为仅使用SSH密钥登录，ansible_ssh_password字段可不配置。

```yaml
## multinode文件
[control]
nestos01 ansible_ssh_user=${USERNAME} ansible_ssh_password=${USERPASSWARD} ansible_become=true

[network]
nestos01

[compute]
nestos02 ansible_ssh_user=${USERNAME} ansible_ssh_password=${USERPASSWARD} ansible_become=true

[monitoring]
nestos01

[storage:children]
compute

[deployment]
localhost       ansible_connection=local become=true
```

#### 3.1.5  配置/ansible/host文件

下述配置仅供参考，详细信息请查询OpenStack官方文档。

**注意：** 本配置文件示例中，形如 **${VALUE}** 字段均需根据实际部署情况自行配置。

**提示：** 如NestOS节点配置为仅使用SSH密钥登录，ansible_ssh_password字段可不配置。

```yaml
nestos01 ansible_ssh_host=${NESTOS_NODE1_IP} ansible_ssh_user=${USERNAME} ansible_ssh_password=${USERPASSWARD}
nestos02 ansible_ssh_host=${NESTOS_NODE2_IP} ansible_ssh_user=${USERNAME} ansible_ssh_password=${USERPASSWARD}
```

#### 3.1.6 填充密码配置文件password.yml

部署中使用的密码存储在/etc/kolla/passwords.yml文件中。此文件中的所有密码默认都是空白的，必须手动或通过运行随机密码生成器来填写。

**注意：** 本配置文件示例中，形如 **${VALUE}** 字段均需根据实际部署情况自行配置。

```bash
## 可通过以下命令生成 OPENSTACKPASSWARD
kolla-genpwd
```

```yaml
## 在文件中修改keystone_admin_password的值
keystone_admin_password: ${OPENSTACKPASSWARD}
```

#### 3.1.7 配置global.yml

globals.yml是Kolla Ansible的主要配置文件，决定openstack安装部署哪些组件。

下述配置仅供参考，详细信息请查询OpenStack官方部署文档。

```yaml
# Valid options are ['centos', 'debian', 'rhel', 'ubuntu']
kolla_base_distro: "centos"
# Valid options are [ binary, source ]
kolla_install_type: "binary"
openstack_release: "wallaby"
kolla_internal_vip_address: "{kolla_internal_vip_address}"
network_interface: "ens2"
api_interface: "{{ network_interface }}"
storage_interface: "{{ network_interface }}"
tunnel_interface: "{{ network_interface }}"
neutron_external_interface: "ens3"
neutron_plugin_agent: "openvswitch"
keepalived_virtual_router_id: "51" 
openstack_logging_debug: "True"
enable_glance: "yes"
enable_haproxy: "yes"
enable_keepalived: "{{ enable_haproxy | bool }}"
enable_keystone: "yes"
enable_mariadb: "yes"
enable_memcached: "yes"
enable_neutron: "{{ enable_openstack_core | bool }}"
enable_nova: "{{ enable_openstack_core | bool }}"
enable_rabbitmq: "{{ 'yes' if om_rpc_transport == 'rabbit' or om_notify_transport == 'rabbit' else 'no' }}"
enable_chrony: "yes"
enable_cinder: "yes"
enable_cinder_backup: "yes"
enable_cinder_backend_lvm: "yes"
enable_cloudkitty: "no"
enable_gnocchi: "no"
enable_heat: "{{ enable_openstack_core | bool }}"
enable_horizon: "yes"
enable_horizon: "{{ enable_openstack_core | bool }}"
enable_horizon_blazar: "{{ enable_blazar | bool }}"
enable_horizon_cloudkitty: "{{ enable_cloudkitty | bool }}"
enable_horizon_murano: "{{ enable_murano | bool }}"
enable_horizon_neutron_lbaas: "{{ enable_neutron_lbaas | bool }}"
enable_horizon_sahara: "{{ enable_sahara | bool }}"
enable_horizon_senlin: "{{ enable_senlin | bool }}"
enable_horizon_watcher: "{{ enable_watcher | bool }}"
enable_ironic: "no"
enable_ironic_ipxe: "no"
enable_ironic_neutron_agent: "no"
enable_kafka: "no"
enable_murano: "no"
enable_neutron_lbaas: "yes"
enable_neutron_sriov: "yes"
enable_neutron_qos: "yes"
enable_nova_ssh: "yes"
enable_openvswitch: "{{ enable_neutron | bool and neutron_plugin_agent != 'linuxbridge' }}"
enable_placement: "{{ enable_nova | bool or enable_zun | bool }}"
enable_sahara: "no"
enable_senlin: "no"
enable_swift: "no"
enable_tempest: "no"
enable_watcher: "no"
keystone_token_provider: 'fernet'
keystone_admin_user: "admin"
keystone_admin_project: "admin"
fernet_token_expiry: 86400
glance_backend_file: "yes"
glance_enable_rolling_upgrade: "no"
cinder_volume_group: "cinder-volumes"
cinder_backup_driver: "lvm"
cinder_backup_share: "lvm"
cinder_backup_mount_options_nfs: "lvm"
nova_compute_virt_type: "qemu"
nova_safety_upgrade: "no"
horizon_backend_database: "{{ enable_murano | bool }}"
```

### 3.2 存储节点

本指南验证方案采用LVM方式管理本地存储，故存储节点需执行以下步骤创建LVM管理卷。

```bash
## 配置数据盘（非系统盘）
pvcreate /dev/sdb
vgcreate3 cinder-volumes /dev/sdb
```

## 四、OpenStack 部署

### 4.1 部署准备

检查multinode配置是否正确

```bash
ansible -i multinode all -m ping
```

### 4.2 部署组件

**注：** 带 * 为主要组件。

| **组件名** | **版本** |
| ---------- | -------- |
| Keystone*  | Wallaby  |
| Nova*      | Wallaby  |
| Glance*    | Wallaby  |
| Neutron*   | Wallaby  |
| Cinder*    | Wallaby  |
| Horizon*   | Wallaby  |
| Heat*      | Wallaby  |
| Haproxy    | Wallaby  |
| Keepalived | Wallaby  |

### 4.3 正式部署

若需查看执行时的详细信息，可在命令后加-vvvv。

**注意：** multinode文件所在路径需手动配置。

```bash
## 引导服务器
kolla-ansible -i ./multinode bootstrap-servers

## 环境检查
## 在kolla-ansible/ansible/roles/prechecks/vars/main.yml中添加NestOS与对应版本
kolla-ansible -i ./multinode prechecks 

## 拉取镜像
kolla-ansible -i ./multinode pull

## 执行部署
kolla-ansible -i ./multinode deploy

## 若需销毁
kolla-ansible destroy -i ./multinode --yes-i-really-really-mean-it
```

如在执行过程中发生错误，请参阅OpenStack官方故障排除指南。

### 4.4 使用 OpenStack

1.  安装openstack客户端

```bash
yum install -y python3-openstackclient
```

2.   OpenStack 需要一个openrc文件，其中设置了管理员用户的凭据，要生成此文件，需执行下述命令。

```bash
kolla-ansible post-deploy
. /etc/kolla/admin-openrc.sh
```

3.   根据安装Kolla Ansible的方式，执行以下脚本创建示例网络、图像等。

```bash
kolla-ansible/tools/init-runonce
```
