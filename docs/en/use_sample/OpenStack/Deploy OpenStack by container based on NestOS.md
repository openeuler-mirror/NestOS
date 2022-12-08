# Deploy OpenStack using container based on NestOS

## 1. Overall Solution

This document provides the deployment solution using container based on NestOS.

This document uses the virtualization platform to create multiple NestOS instances as the OpenStack verification environment. In bare metal environment, you can also deploy OpenStack by referring to this document and the NestOS bare metal installation document.

The verification environment reference is as follows:

-   Basic Information
    -   Deployment Node OS：openEuler 21.09
    -   OpenStack Version：Wallaby
    -   Kolla-ansible Version：12.0.0

-   Instance Configuration
    -   NestOS Version：nestos-22.03.20220329-qemu.x86_64.qcow2
    -   Kernel Version：5.10.0-52.0.0.26.oe2203.x86_64
    -   NIC * 2

-   Resource Architecture Description
    -   The CPU, Memory and Hard Disk Storage Capacity listed in the table are the minimum requirements.
    -   NIC 2 is dedicated to the Neutron external or public network. It can be a vlan or a flat network based on the network creation mode. This NIC should be active without the IP address. Otherwise, the instance cannot access the external network.
    -   If the Storage Node uses the local storage scheme, such as LVM, you can add the second hard disk.

| Role                         | Hostname    | NIC 1           | NIC 2    | CPU  | MEM | HD 1 | HD 2 |
| ---------------------------- | --------- | --------------- | -------- | ---- | ---- | ----- | ----- |
| Deployment Node                     | localhost | IP              |          |      |      |       |       |
| Control Node、Network Node、Monitoring Node | nestos01 | NESTOS_NODE1_IP |  | 4C   | 8G   | 40G   |       |
| Compute Node、Storage Node           | nestos02  | NESTOS_NODE2_IP |  | 4C   | 8G   | 40G   | 40G   |

## 2. Create and configure the NestOS instance

NestOS implements batch configuration of nodes through the ignition file mechanism. This section provides a brief overview of the ignition file generation method and a reference for configuring the ignition file when deploying OpenStack using container.

This guide uses libvirt to create the NestOS instance and provides corresponding steps and commands for reference. For other deployment methods, please see the NestOS installation and deployment documents.

**Note:** The ignition file may need to be adjusted for deployment with other ways.

### 2.1 Generate the ignition file

When deploying OpenStack containerized，the ignition configuration of NestOS instance is divided into two parts: system configuration and OpenStack deployment environment initialization. The main configurations are as follows:

| Part                    | Configuration Items                                           | Purpose                                   |
| ----------------------- | ------------------------------------------------ | -------------------------------------- |
| System Configuration                | passwd                                           | Configure NestOS login users and authentication |
| Hostname                  | Configure the hostname of NestOS instance                             |                                        |
| NIC 1                   | This NIC is responsible for deploying, operating and maintaining the NestOS instance, plus providing the basic network environment. |                                        |
| Time zone                    | Configure the default time zone for NestOS instance. Otherwise, the /etc/localtime file does not exist. |                                        |
| Initialize | Kernel parameters                                         | Partial kernel parameters must be enabled in the OpenStack deployment environment    |
| NIC 2                   | This NIC is only used by Neutron                         |                                        |
| Python          | The python environment is required.                    |                                        |
| Disable selinux             | Selinux must be disabled.                   |                                        |
| Time Sync            | Sync the cluster time through the chronyd service   |                                        |
| Storage Configuration                | This parameter is mandatory for Storage Node                |                                        |

The specific steps are as follows:

#### 2.1.1 Butane

Butane can convert a bu file into an ignition file. At this stage, you can run the following command to pull the Butane container image. The openEuler software source will be provided later.

```bash
docker pull quay.io/coreos/butane:latest
```

#### 2.1.2 Generate the login password

If you plan to use the password to access the NestOS instance, run the following command to generate **${PASSWORD_HASH}** for the ignition file.

```bash
openssl passwd -1 -salt yoursalt
```

#### 2.1.3 Generate the SSH key pair

If you plan to use an SSH public key to access the NestOS instance, run the following command to generate the SSH key pair. The generated directory uses /root/.ssh/ as an example. If the key pair already exists, skip this step:

```bash
ssh-keygen -N '' -f /root/.ssh/id_rsa
```

View the public key file id_rsa.pub to obtain the SSH public key information **${ssh-rsa}** for the ignition file.

```bash
cat /root/.ssh/id_rsa.pub
```

#### 2.1.4 Prepare the Bu file

Before generating the ignition file for NestOS instance, you need to write the bu configuration file. Read the NestOS official documentation for more details.

Create a bu configuration file named nestos_config.bu. The following example is used to create a NestOS instance for OpenStack cluster deployment.

**Warning:** Using this configuration file, selinux will be turned off.

**Note:** In the following example, fields in the form of **${VALUE}** must be configured based on the actual deployment. Some field generation methods are provided above.

```yaml
variant: fcos
version: 1.1.0
## passwd
passwd:
  users:
    - name: nest
      ## login password
      password_hash: "${PASSWORD_HASH}"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      ## SSH public key
      ssh_authorized_keys:
        - "${SSH-RSA}"
storage:
  files:
    ## Hostname
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: ${HOSTNAME}
    ## Kernel parameter - part1
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
      ## NIC 1，use the ens2 as an example. If there are many nodes, you can choose DHCP.
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
    ## NIC 2，use the ens3 as an example.
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
    ## Timezone
    - path: /etc/localtime
      ## Use the Shanghai time zone as an example: target: ../usr/share/zoneinfo/Asia/Shanghai
      target: ${YOUR_ZONEINFO_PATH}
systemd:
  units:
    ## Python
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
    ## Disable selinux
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
    ## Kernel parameter - part2
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
    ## Time Sync
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
     ## Storage configuration, using LVM as an example
     ## TODO
```

#### 2.1.5 Generate the ignition file

After the configuration is written, convert the above nestos_config.bu to the nestos_config.ign through the Butane tool. The following is the conversion command through the Butane container environment.

```bash
docker run --interactive --rm quay.io/coreos/butane:latest --pretty --strict < nestos_config.bu > nestos_config.ign
```

### 2.2 Create the NestOS instance

This guide uses libvirt to create the NestOS instance. The following steps are for reference. If you use other methods to install and deploy NestOS, refer to the NestOS installation and deployment documentation and use the ignition configuration file generated in 2.1 to configure the NestOS.

**Warning:** In the configuration file, fields in the form of **${VALUE}** must be configured based on the actual deployment.

#### 2.2.1 Create the independent network

The NestOS instance must have two NICs for OpenStack deployment, and the final network cannot be the same subnet. The two NICs are planned to connect to different networks in this document. Therefore, you need to create an independent network. If you plan to use VLAN, skip this step.

The libvirt host creates a configuration file named virbr1.xml with the following contents:

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

The libvirt host runs the following command to create a new network virbr1:

```bash
virsh net-create --file virbr1.xml
```

#### 2.2.2 Use libvirt to create NestOS instance

Run the following commands on the libvirt host to create a NestOS VM: vcpus, ram, and disk are the minimum requirements and can be adjusted by referring to the virt-install manual.

```bash
virt-install --name=${NAME} --vcpus=4 --ram=8192 --import --network=bridge=virbr0 --graphics=none --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${ignition_FILE_PATH}" --disk=size=40,backing_store=${NESTOS_RELEASE_QCOW2_PATH} --network=bridge=virbr1 --disk=size=40
```

## 3. OpenStack Configuration

Kolla-ansible is the general solution to deploy the OpenStack using containers, so does based on NestOS deployment.The following configuration steps are common for Kolla-ansible deployment, and is not directly related to NestOS.

The configuration solution provided in this section is for reference only. For more information, please see the OpenStack official deployment documents.

### 3.1 Deployment Node

The deployment node can be any Linux node that can access the NestOS instance. Because NestOS is built based on openEuler ecosystem, it is recommended that the deployment node use the openEuler operating system to ensure that Kolla-ansible software packages have the same version and avoid exceptions due to version differences.

In the following verification environment, the hostname of the deployment node is localhost and the OS is openEuler 21.09.

#### 3.1.1 No secret login to the NestOS instance

**Warning:** In the configuration file, fields in the form of **${VALUE}** must be configured based on the actual deployment.

Add NestOS instance information in /etc/hosts to connect through the hostname.

```bash
## Add NestOS instance information in /etc/hosts
${NESTOS_NODE1_IP} nestos01
${NESTOS_NODE2_IP} nestos02
```

Ensure the deployment node can access the NestOS instance through SSH using the hostname.

```bash
## If the SSH public key has been configured in the ignition file, skip the following steps
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub ${nest}@nestos01
ssh-copy-id -i ~/.ssh/id_rsa.pub ${nest}@nestos02

## Testing
ssh nest@nestos01
ssh nest@nestos02
```

#### 3.1.2 Install Kolla Ansible

```bash
yum install -y openstack-kolla openstack-kolla-ansible
```

#### 3.1.3 Config Ansible

Add the following configuration to /etc/ansible/ansible.cfg.

```bash
[defaults]
host_key_checking=False
pipelining=True
forks=100
```

#### 3.1.4 Config the Inventory file

Inventory is an Ansible file where we specify hosts and the groups that they belong to. We can use this to define node roles and access credentials.

Kolla Ansible comes with all-in-one and multinode example inventory files. The difference between them is that the former is ready for deploying single node OpenStack on localhost. If you need to use separate host or more than one node, edit multinode inventory:

This solution uses the multinode inventory file and the following configuration information is for reference. For details, please read the OpenStack official documentation.

**Warning:** In the configuration file, fields in the form of **${VALUE}** must be configured based on the actual deployment.

**Note:** If the NestOS instance uses the SSH key to login, the ansible_ssh_password field is optional.

```yaml
## multinode
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

#### 3.1.5  Config /ansible/host

The following configuration is for reference only. For details, see the OpenStack official documentation.

**Warning:** In the configuration file, fields in the form of **${VALUE}** must be configured based on the actual deployment.

**Note:** If the NestOS instance uses the SSH key to login, the ansible_ssh_password field is optional.

```yaml
nestos01 ansible_ssh_host=${NESTOS_NODE1_IP} ansible_ssh_user=${USERNAME} ansible_ssh_password=${USERPASSWARD}
nestos02 ansible_ssh_host=${NESTOS_NODE2_IP} ansible_ssh_user=${USERNAME} ansible_ssh_password=${USERPASSWARD}
```

#### 3.1.6 Fill password.yml

The passwords used in the deployment are stored in /etc/kolla/passwords.yml. All passwords in this file are blank by default and must be filled in either manually or by running a random password generator.

**Warning:** In the configuration file, fields in the form of **${VALUE}** must be configured based on the actual deployment.

```bash
## generate OPENSTACKPASSWARD
kolla-genpwd
```

```yaml
## change keystone_admin_password
keystone_admin_password: ${OPENSTACKPASSWARD}
```

#### 3.1.7 Config global.yml

The globals.yml is the main configuration file for Kolla Ansible. It determines which components are installed and deployed in openstack.

**Note:** If the NestOS instance uses the SSH key to login, the ansible_ssh_password field is optional.

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

### 3.2 Storage Node

In this document, local storage devices are managed in LVM mode. Therefore, use the following steps to create LVM management volumes for storage nodes.

```bash
## Config the Data Disks (Non-System Disks)
pvcreate /dev/sdb
vgcreate3 cinder-volumes /dev/sdb
```

## 4. OpenStack Deployment

### 4.1 Preparation

Check whether the configuration of inventory is correct or not, run:

```bash
ansible -i multinode all -m ping
```

### 4.2 Components

**注：** With * are the main components.

| **Components** | **Version** |
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

### 4.3 Deployment

To view the details, add -vvvv after the command.

**Warning:** The path of the multinode file needs to be config.

```bash
## Bootstrap servers with kolla deploy dependencies
kolla-ansible -i ./multinode bootstrap-servers

## Do pre-deployment checks for hosts
kolla-ansible -i ./multinode prechecks 

## Pull the images
kolla-ansible -i ./multinode pull

## Finally proceed to actual OpenStack deployment
kolla-ansible -i ./multinode deploy

## If you need destroy
kolla-ansible destroy -i ./multinode --yes-i-really-really-mean-it
```

If have any error, please see the OpenStack official troubleshooting guide.

### 4.4 Using OpenStack

a. Install the OpenStack CLI client

```bash
yum install -y python3-openstackclient
```

b. OpenStack requires an openrc file where credentials for admin user are set. To generate this file:

```bash
kolla-ansible post-deploy
. /etc/kolla/admin-openrc.sh
```

c. Depending on how you installed Kolla Ansible, there is a script that will create example networks, images, and so on.

```bash
kolla-ansible/tools/init-runonce
```
