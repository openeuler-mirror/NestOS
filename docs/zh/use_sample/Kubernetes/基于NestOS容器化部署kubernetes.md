# 	基于NestOS容器化部署Kubernetes

​		

## 整体方案

Kubernetes（k8s）是为容器服务而生的一个可移植容器的编排管理工具。本指南旨在提供NestOS快速容器化部署k8s的解决方案。该方案以虚拟化平台创建多个NestOS节点作为部署k8s的验证环境，并通过编写Ignition文件的方式，提前将k8s所需的环境配置到一个yaml文件中。在安装NestOS操作系统的同时，即可完成对k8s所需资源的部署并创建节点。裸金属环境也可以参考本文并结合NestOS裸金属安装文档完成k8s部署。

- 版本信息：

  - NestOS镜像版本：22.09

  - k8s版本：v1.23.10

  - isulad版本：2.0.16

- 安装要求
  - 每台机器2GB或更多的RAM
  - CPU2核心及以上
  - 集群中所有机器之间网络互通
  - 节点之中不可以有重复的主机名
  - 可以访问外网，需要拉取镜像
  - 禁止swap分区
  - 关闭selinux
- 部署内容
  - NestOS镜像以集成isulad和kubeadm、kubelet、kubectl等二进制文件
  - 部署k8s Master节点
  - 部署容器网络插件
  - 部署k8s Node节点，将节点加入k8s集群中

## K8S节点配置

NestOS通过Ignition文件机制实现节点批量配置。本章节简要介绍Ignition文件的生成方法，并提供容器化部署k8s时的Ignition配置示例。NestOS节点系统配置内容如下：

| 配置项       | 用途                                   |
| ------------ | -------------------------------------- |
| passwd       | 配置节点登录用户和访问鉴权等相关信息   |
| hostname     | 配置节点的hostname                     |
| 时区         | 配置节点的默认时区                     |
| 内核参数     | k8s部署环境需要开启部分内核参数        |
| 关闭selinux  | k8s部署环境需要关闭selinux             |
| 设置时间同步 | k8s部署环境通过chronyd服务同步集群时间 |

### 生成登录密码

使用密码登录方式访问NestOS实例，可使用下述命令生成${PASSWORD_HASH} 供点火文件配置使用：

```
openssl passwd -1 -salt yoursalt
```

### 生成ssh密钥对

采用ssh公钥方式访问NestOS实例，可通过下述命令生成ssh密钥对：

```
ssh-keygen -N '' -f /root/.ssh/id_rsa
```

查看公钥文件id_rsa.pub，获取ssh公钥信息后供Ignition文件配置使用：

```
cat /root/.ssh/id_rsa.pub
```

### 编写butane配置文件

本配置文件示例中，下列字段均需根据实际部署情况自行配置。部分字段上文提供了生成方法：

- ${PASSWORD_HASH}：指定节点的登录密码
- ${SSH-RSA}：配置节点的公钥信息
- ${MASTER_NAME}：配置主节点的hostname
- ${MASTER_IP}：配置主节点的IP
- ${MASTER_SEGMENT}：配置主节点的网段
- ${NODE_NAME}：配置node节点的hostname
- ${NODE_IP}：配置node节点的IP
- ${GATEWAY}：配置节点网关
- ${service-cidr}：指定service分配的ip段
- ${pod-network-cidr}：指定pod分配的ip段
- ${image-repository}：指定镜像仓库地址，例：https://registry.cn-hangzhou.aliyuncs.com
- ${token}：加入集群的token信息，通过master节点获取

master节点butane配置文件示例：

```yaml
variant: fcos
version: 1.1.0
##passwd相关配置
passwd:
  users:
    - name: root
      ##登录密码
      password_hash: "${PASSWORD_HASH}"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      ##ssh公钥信息
      ssh_authorized_keys:
        - "${SSH-RSA}"
storage:
  directories:
  - path: /etc/systemd/system/kubelet.service.d
    overwrite: true
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: ${MASTER_NAME}
    - path: /etc/hosts
      mode: 0644
      overwrite: true
      contents:
        inline: |
          127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
          ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
          ${MASTER_IP} ${MASTER_NAME}
          ${NODE_IP} ${NODE_NAME}
    - path: /etc/NetworkManager/system-connections/ens2.nmconnection
      mode: 0600
      overwrite: true
      contents:
        inline: |
          [connection]
          id=ens2
          type=ethernet
          interface-name=ens2
          [ipv4]
          address1=${MASTER_IP}/24,${GATEWAY}
          dns=8.8.8.8
          dns-search=
          method=manual
    - path: /etc/sysctl.d/kubernetes.conf
      mode: 0644
      overwrite: true
      contents:
        inline: |
          net.bridge.bridge-nf-call-iptables=1
          net.bridge.bridge-nf-call-ip6tables=1
          net.ipv4.ip_forward=1
    - path: /etc/isulad/daemon.json
      mode: 0644
      overwrite: true
      contents:
        inline: |
          {
              "exec-opts": ["native.cgroupdriver=systemd"],
              "group": "isula",
              "default-runtime": "lcr",
              "graph": "/var/lib/isulad",
              "state": "/var/run/isulad",
              "engine": "lcr",
              "log-level": "ERROR",
              "pidfile": "/var/run/isulad.pid",
              "log-opts": {
                  "log-file-mode": "0600",
                  "log-path": "/var/lib/isulad",
                  "max-file": "1",
                  "max-size": "30KB"
              },
              "log-driver": "stdout",
              "container-log": {
                  "driver": "json-file"
              },
              "hook-spec": "/etc/default/isulad/hooks/default.json",
              "start-timeout": "2m",
              "storage-driver": "overlay2",
              "storage-opts": [
                  "overlay2.override_kernel_check=true"
              ],
              "registry-mirrors": [
                  "docker.io"
              ],
              "insecure-registries": [
                  "${image-repository}"
              ],
              "pod-sandbox-image": "k8s.gcr.io/pause:3.6",
              "native.umask": "secure",
              "network-plugin": "cni",
              "cni-bin-dir": "/opt/cni/bin",
              "cni-conf-dir": "/etc/cni/net.d",
              "image-layer-check": false,
              "use-decrypted-key": true,
              "insecure-skip-verify-enforce": false,
              "cri-runtimes": {
                  "kata": "io.containerd.kata.v2"
              }
          }
    - path: /root/pull_images.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #!/bin/sh
          KUBE_VERSION=v1.23.10
          KUBE_PAUSE_VERSION=3.6
          ETCD_VERSION=3.5.1-0
          DNS_VERSION=v1.8.6
          CALICO_VERSION=v3.19.4
          username=${image-repository}
          images=(
                  kube-proxy:${KUBE_VERSION}
                  kube-scheduler:${KUBE_VERSION}
                  kube-controller-manager:${KUBE_VERSION}
                  kube-apiserver:${KUBE_VERSION}
                  pause:${KUBE_PAUSE_VERSION}
                  etcd:${ETCD_VERSION}
          )
          for image in ${images[@]}
          do
              isula pull ${username}/${image}
              isula tag ${username}/${image} k8s.gcr.io/${image}
              isula rmi ${username}/${image}
          done
          isula pull ${username}/coredns:${DNS_VERSION}
          isula tag ${username}/coredns:${DNS_VERSION} k8s.gcr.io/coredns/coredns:${DNS_VERSION}
          isula rmi ${username}/coredns:${DNS_VERSION}
          isula pull calico/node:${CALICO_VERSION}
          isula pull calico/cni:${CALICO_VERSION}
          isula pull calico/kube-controllers:${CALICO_VERSION}
          isula pull calico/pod2daemon-flexvol:${CALICO_VERSION}
          touch /var/log/pull-images.stamp
    - path: /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
      mode: 0644
      contents:
        inline: |
          # Note: This dropin only works with kubeadm and kubelet v1.11+
          [Service]
          Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
          Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
          # This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
          EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
          # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
          # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
          EnvironmentFile=-/etc/sysconfig/kubelet
          ExecStart=
          ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
    - path: /root/init-config.yaml
      mode: 0644
      contents:
        inline: |
          apiVersion: kubeadm.k8s.io/v1beta2
          kind: InitConfiguration
          nodeRegistration:
            criSocket: /var/run/isulad.sock
            name: k8s-master01
            kubeletExtraArgs:
              volume-plugin-dir: "/opt/libexec/kubernetes/kubelet-plugins/volume/exec/"
          ---
          apiVersion: kubeadm.k8s.io/v1beta2
          kind: ClusterConfiguration
          controllerManager:
            extraArgs:
              flex-volume-plugin-dir: "/opt/libexec/kubernetes/kubelet-plugins/volume/exec/"
          kubernetesVersion: v1.23.10
          imageRepository: k8s.gcr.io
          controlPlaneEndpoint: "${MASTER_IP}:6443"
          networking:
            serviceSubnet: "${service-cidr}"
            podSubnet: "${pod-network-cidr}"
            dnsDomain: "cluster.local"
          dns:
            type: CoreDNS
            imageRepository: k8s.gcr.io/coredns
            imageTag: v1.8.6
  links:
    - path: /etc/localtime
      target: ../usr/share/zoneinfo/Asia/Shanghai

systemd:
  units:
    - name: kubelet.service
      enabled: true
      contents: |
        [Unit]
        Description=kubelet: The Kubernetes Node Agent
        Documentation=https://kubernetes.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        ExecStart=/usr/bin/kubelet
        Restart=always
        StartLimitInterval=0
        RestartSec=10

        [Install]
        WantedBy=multi-user.target

    - name: set-kernel-para.service
      enabled: true
      contents: |
        [Unit]
        Description=set kernel para for Kubernetes
        ConditionPathExists=!/var/log/set-kernel-para.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=modprobe br_netfilter
        ExecStart=sysctl -p /etc/sysctl.d/kubernetes.conf
        ExecStart=/bin/touch /var/log/set-kernel-para.stamp

        [Install]
        WantedBy=multi-user.target

    - name: pull-images.service
      enabled: true
      contents: |
        [Unit]
        Description=pull images for kubernetes
        ConditionPathExists=!/var/log/pull-images.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=systemctl start isulad
        ExecStart=systemctl enable isulad
        ExecStart=sh /root/pull_images.sh

        [Install]
        WantedBy=multi-user.target

    - name: disable-selinux.service
      enabled: true
      contents: |
        [Unit]
        Description=disable selinux for kubernetes
        ConditionPathExists=!/var/log/disable-selinux.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config"
        ExecStart=setenforce 0
        ExecStart=/bin/touch /var/log/disable-selinux.stamp

        [Install]
        WantedBy=multi-user.target

    - name: set-time-sync.service
      enabled: true
      contents: |
        [Unit]
        Description=set time sync for kubernetes
        ConditionPathExists=!/var/log/set-time-sync.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "sed -i '3aserver ntp1.aliyun.com iburst' /etc/chrony.conf"
        ExecStart=bash -c "sed -i '24aallow ${MASTER_SEGMENT}' /etc/chrony.conf"
        ExecStart=bash -c "sed -i '26alocal stratum 10' /etc/chrony.conf"
        ExecStart=systemctl restart chronyd.service
        ExecStart=/bin/touch /var/log/set-time-sync.stamp

        [Install]
        WantedBy=multi-user.target

    - name: init-cluster.service
      enabled: true
      contents: |
        [Unit]
        Description=init kubernetes cluster
        Requires=set-kernel-para.service pull-images.service disable-selinux.service set-time-sync.service
        After=set-kernel-para.service pull-images.service disable-selinux.service set-time-sync.service
        ConditionPathExists=/var/log/set-kernel-para.stamp
        ConditionPathExists=/var/log/set-time-sync.stamp
        ConditionPathExists=/var/log/disable-selinux.stamp
        ConditionPathExists=/var/log/pull-images.stamp
        ConditionPathExists=!/var/log/init-k8s-cluster.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=kubeadm init --config=/root/init-config.yaml --upload-certs
        ExecStart=/bin/touch /var/log/init-k8s-cluster.stamp

        [Install]
        WantedBy=multi-user.target


    - name: install-cni-plugin.service
      enabled: true
      contents: |
        [Unit]
        Description=install cni network plugin for kubernetes
        Requires=init-cluster.service
        After=init-cluster.service

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "curl https://docs.projectcalico.org/v3.19/manifests/calico.yaml -o /root/calico.yaml"
        ExecStart=/bin/sleep 6
        ExecStart=bash -c "sed -i 's#usr/libexec/#opt/libexec/#g' /root/calico.yaml"
        ExecStart=kubectl apply -f /root/calico.yaml --kubeconfig=/etc/kubernetes/admin.conf

        [Install]
        WantedBy=multi-user.target

```

Node节点butane配置文件示例：

```yaml
variant: fcos
version: 1.1.0
passwd:
  users:
    - name: root
      password_hash: "${PASSWORD_HASH}"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      ssh_authorized_keys:
        - "${SSH-RSA}"
storage:
  directories:
  - path: /etc/systemd/system/kubelet.service.d
    overwrite: true
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: ${NODE_NAME}
    - path: /etc/hosts
      mode: 0644
      overwrite: true
      contents:
        inline: |
          127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
          ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
          ${MASTER_IP} ${MASTER_NAME}	
          ${NODE_IP} ${NODE_NAME}
    - path: /etc/NetworkManager/system-connections/ens2.nmconnection
      mode: 0600
      overwrite: true
      contents:
        inline: |
          [connection]
          id=ens2
          type=ethernet
          interface-name=ens2
          [ipv4]
          address1=${NODE_IP}/24,${GATEWAY}
          dns=8.8.8.8;
          dns-search=
          method=manual
    - path: /etc/sysctl.d/kubernetes.conf
      mode: 0644
      overwrite: true
      contents:
        inline: |
          net.bridge.bridge-nf-call-iptables=1
          net.bridge.bridge-nf-call-ip6tables=1
          net.ipv4.ip_forward=1
    - path: /etc/isulad/daemon.json
      mode: 0644
      overwrite: true
      contents:
        inline: |
          {
              "exec-opts": ["native.cgroupdriver=systemd"],
              "group": "isula",
              "default-runtime": "lcr",
              "graph": "/var/lib/isulad",
              "state": "/var/run/isulad",
              "engine": "lcr",
              "log-level": "ERROR",
              "pidfile": "/var/run/isulad.pid",
              "log-opts": {
                  "log-file-mode": "0600",
                  "log-path": "/var/lib/isulad",
                  "max-file": "1",
                  "max-size": "30KB"
              },
              "log-driver": "stdout",
              "container-log": {
                  "driver": "json-file"
              },
              "hook-spec": "/etc/default/isulad/hooks/default.json",
              "start-timeout": "2m",
              "storage-driver": "overlay2",
              "storage-opts": [
                  "overlay2.override_kernel_check=true"
              ],
              "registry-mirrors": [
                  "docker.io"
              ],
              "insecure-registries": [
                  "${image-repository}"
              ],
              "pod-sandbox-image": "k8s.gcr.io/pause:3.6",
              "native.umask": "secure",
              "network-plugin": "cni",
              "cni-bin-dir": "/opt/cni/bin",
              "cni-conf-dir": "/etc/cni/net.d",
              "image-layer-check": false,
              "use-decrypted-key": true,
              "insecure-skip-verify-enforce": false,
              "cri-runtimes": {
                  "kata": "io.containerd.kata.v2"
              }
          }
    - path: /root/pull_images.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #!/bin/sh
          KUBE_VERSION=v1.23.10
          KUBE_PAUSE_VERSION=3.6
          ETCD_VERSION=3.5.1-0
          DNS_VERSION=v1.8.6
          CALICO_VERSION=v3.19.4
          username=${image-repository}
          images=(
                  kube-proxy:${KUBE_VERSION}
                  kube-scheduler:${KUBE_VERSION}
                  kube-controller-manager:${KUBE_VERSION}
                  kube-apiserver:${KUBE_VERSION}
                  pause:${KUBE_PAUSE_VERSION}
                  etcd:${ETCD_VERSION}
          )
          for image in ${images[@]}
          do
              isula pull ${username}/${image}
              isula tag ${username}/${image} k8s.gcr.io/${image}
              isula rmi ${username}/${image}
          done
          isula pull ${username}/coredns:${DNS_VERSION}
          isula tag ${username}/coredns:${DNS_VERSION} k8s.gcr.io/coredns/coredns:${DNS_VERSION}
          isula rmi ${username}/coredns:${DNS_VERSION}
          touch /var/log/pull-images.stamp
    - path: /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
      mode: 0644
      contents:
        inline: |
          # Note: This dropin only works with kubeadm and kubelet v1.11+
          [Service]
          Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
          Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
          # This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
          EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
          # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
          # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
          EnvironmentFile=-/etc/sysconfig/kubelet
          ExecStart=
          ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
    - path: /root/join-config.yaml
      mode: 0644
      contents:
        inline: |
          apiVersion: kubeadm.k8s.io/v1beta3
          caCertPath: /etc/kubernetes/pki/ca.crt
          discovery:
            bootstrapToken:
              apiServerEndpoint: ${MASTER_IP}:6443
              token: ${token}
              unsafeSkipCAVerification: true
            timeout: 5m0s
            tlsBootstrapToken: ${token}
          kind: JoinConfiguration
          nodeRegistration:
            criSocket: /var/run/isulad.sock
            imagePullPolicy: IfNotPresent
            name: ${NODE_NAME}
            taints: null
  links:
    - path: /etc/localtime
      target: ../usr/share/zoneinfo/Asia/Shanghai

systemd:
  units:
    - name: kubelet.service
      enabled: true
      contents: |
        [Unit]
        Description=kubelet: The Kubernetes Node Agent
        Documentation=https://kubernetes.io/docs/
        Wants=network-online.target
        After=network-online.target

        [Service]
        ExecStart=/usr/bin/kubelet
        Restart=always
        StartLimitInterval=0
        RestartSec=10

        [Install]
        WantedBy=multi-user.target

    - name: set-kernel-para.service
      enabled: true
      contents: |
        [Unit]
        Description=set kernel para for kubernetes
        ConditionPathExists=!/var/log/set-kernel-para.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=modprobe br_netfilter
        ExecStart=sysctl -p /etc/sysctl.d/kubernetes.conf
        ExecStart=/bin/touch /var/log/set-kernel-para.stamp

        [Install]
        WantedBy=multi-user.target

    - name: pull-images.service
      enabled: true
      contents: |
        [Unit]
        Description=pull images for kubernetes
        ConditionPathExists=!/var/log/pull-images.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=systemctl start isulad
        ExecStart=systemctl enable isulad
        ExecStart=sh /root/pull_images.sh

        [Install]
        WantedBy=multi-user.target

    - name: disable-selinux.service
      enabled: true
      contents: |
        [Unit]
        Description=disable selinux for kubernetes
        ConditionPathExists=!/var/log/disable-selinux.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config"
        ExecStart=setenforce 0
        ExecStart=/bin/touch /var/log/disable-selinux.stamp

        [Install]
        WantedBy=multi-user.target

    - name: set-time-sync.service
      enabled: true
      contents: |
        [Unit]
        Description=set time sync for kubernetes
        ConditionPathExists=!/var/log/set-time-sync.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=bash -c "sed -i '3aserver ${MASTER_IP}' /etc/chrony.conf"
        ExecStart=systemctl restart chronyd.service
        ExecStart=/bin/touch /var/log/set-time-sync.stamp

        [Install]
        WantedBy=multi-user.target

    - name: join-cluster.service
      enabled: true
      contents: |
        [Unit]
        Description=node join kubernetes cluster
        Requires=set-kernel-para.service pull-images.service disable-selinux.service set-time-sync.service
        After=set-kernel-para.service pull-images.service disable-selinux.service set-time-sync.service
        ConditionPathExists=/var/log/set-kernel-para.stamp
        ConditionPathExists=/var/log/set-time-sync.stamp
        ConditionPathExists=/var/log/disable-selinux.stamp
        ConditionPathExists=/var/log/pull-images.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=kubeadm join --config=/root/join-config.yaml

        [Install]
        WantedBy=multi-user.target

```

### 生成Ignition文件

为了方便使用者读、写，Ignition文件增加了一步转换过程。将Butane配置文件（yaml格式）转换成Ignition文件（json格式），并使用生成的Ignition文件引导新的NestOS镜像。Butane配置转换成Ignition配置命令：

```
podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < your_config.bu > transpiled_config.ign
```



## K8S集群搭建

利用上一节配置的Ignition文件，执行下述命令创建k8s集群的Master节点，其中 vcpus、ram 和 disk 参数可自行调整，详情可参考 virt-install 手册。

```
virt-install --name=${NAME} --vcpus=4 --ram=8192 --import --network=bridge=virbr0 --graphics=none --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_FILE_PATH}" --disk=size=40,backing_store=${NESTOS_RELEASE_QCOW2_PATH} --network=bridge=virbr1 --disk=size=40
```

Master节点系统安装成功后，系统后台会起一系列环境配置服务，其中set-kernel-para.service会配置内核参数，pull-images.service会拉取集群所需的镜像，disable-selinux.service会关闭selinux，set-time-sync.service服务会设置时间同步，init-cluster.service会初始化集群，之后install-cni-plugin.service会安装cni网络插件。整个集群部署过程中由于要拉取镜像，所以需要等待几分钟。

通过kubectl get pods -A命令可以查看是否所有pod状态都为running：

![](/docs/zh/graph/K8S容器化部署/k1.PNG)

在Master节点上通过下面命令查看token：

```
kubeadm token list
```

将查询到的token信息添加到Node节点的ignition文件中，并利用该ignition文件创建Node节点。Node节点创建完成后，在Master节点上通过执行kubectl get nodes命令，可以查看Node节点是否加入到了集群中。

![](/docs/zh/graph/K8S容器化部署/k2.PNG)

至此，k8s部署成功
