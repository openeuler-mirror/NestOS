# Deploy KubeSphere containerized based on NestOS

##  Overall Solution

KubeSphere is an **application-centered enterprise-level distributed container platform** built on Kubernetes, which provides easy-to-use operation interface and wizard operation mode.It not only reduces the learning cost of using container scheduling platform for users, but also greatly reduces the complexity of daily work of development, testing and operation and maintenance. It is designed to address the pain points of storage, networking, security and ease of use that exist in Kubernetes itself.This guide is intended to provide a solution for NestOS containerized deployment of KubeSphere.This scheme uses the virtualization platform to create several NestOS nodes as the verification environment for deploying Kubernetes, builds the community version of Kubernetes platform, and deploys KubeSphere on Kubernetes.You can also refer to this article and the NestOS bare metal installation document to complete the KubeSphere deployment in the bare metal environment.

- Version Information:
  - NestOS Image version:22.09
  - Community k8s version:v1.20.2
  - isulad version:2.0.16
  - KubeSphere version:v3.3.1
- Installation Requirements
  - 4GB or more RAM per machine
  - 2 cores or higher for cpu
  - All machines in the cluster are communicating properly with each other
  - The host name of a node must be unique
  - Internet access to pull the image
  - disable swap partition
  - disable selinux
- Deployment Contents
  - NestOS image that integrates isulad and community edition binaries such as kubeadm, kubelet, kubectl, etc
  - Deploy the k8s Master node
  - Deploy the container network plug-in
  - Deploy the k8s Node and add it to the k8s cluster
  - Deploy KubeSphere

## Configure the K8S node

NestOS implements node batch configuration through the Ignition file mechanism.This section Outlines the Ignition file generation method and provides an example of the Ignition configuration when deploying k8s in a container.The system configuration of the NestOS node is as follows:

| Configuration Items      | use                                   |
| ------------ | -------------------------------------- |
| passwd       | Configure node login user and access authorization and other related information   |
| hostname     | Configure the hostname of the node                    |
| time zone         | Config the default time zone for the node                    |
| Kernel parameters     | The k8s deployment environment requires some kernel parameters to be enabled        |
| disable selinux  | The k8s deployment environment requires selinux to be turned off             |
| Setting up time synchronization | The k8s deployment environment synchronizes the cluster time through the chronyd service |

### Generate login password

To access the NestOS instance using password login, use the following command to generate ${PASSWORD_HASH} for the ignition file configuration:

```
openssl passwd -1 -salt yoursalt
```

### Generate ssh key pairs

To access the NestOS instance with ssh public keys, the ssh key pair can be generated with the following command:

```
ssh-keygen -N '' -f /root/.ssh/id_rsa
```

Check the public key file id_rsa.pub to get the ssh public key information and use it for Ignition file configuration:

```
cat /root/.ssh/id_rsa.pub
```

### Write the butane configuration file

In this example configuration file, each of the following fields should be configured according to your deployment.Some fields have generation methods provided above:

- ${PASSWORD_HASH}：Specifies the login password for the node
- ${SSH-RSA}：Configure the public key information of the node
- ${MASTER_NAME}：Configure the hostname of the master node
- ${MASTER_IP}：Configure the IP of the master node
- ${MASTER_SEGMENT}：Configure the network segment of the master node
- ${NODE_NAME}：Configure the hostname of the node node
- ${NODE_IP}：Configure the IP address of node
- ${GATEWAY}：Configure the node gateway
- ${service-cidr}：Specifies the ip segment allocated by the service
- ${pod-network-cidr}：Specifies the ip segment for pod allocation
- ${image-repository}：Specify the mirror repository address, for example:https://registry.cn-hangzhou.aliyuncs.com
- ${token}：The token information to join the cluster is obtained through the master node
- ${NET_CARD}：Node IP network card name, for example:ens2

Example butane configuration file for master node:

```yaml
variant: fcos
version: 1.1.0
##passwd related configuration
passwd:
  users:
    - name: root
      ##Login Password
      password_hash: "${PASSWORD_HASH}"
      "groups": [
          "adm",
          "sudo",
          "systemd-journal",
          "wheel"
        ]
      ##ssh public key information
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
          id=${NET_CARD}
          type=ethernet
          interface-name=${NET_CARD}
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
          controlPlaneEndpoint: "192.168.122.110:6443"
          networking:
            serviceSubnet: "10.96.0.0/16"
            podSubnet: "10.100.0.0/16"
            dnsDomain: "cluster.local"
          dns:
            type: CoreDNS
            imageRepository: k8s.gcr.io/coredns
            imageTag: v1.8.6
    - path: /root/default-storage.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #!/bin/sh
          export KUBECONFIG=/etc/kubernetes/admin.conf
          kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    - path: /root/detect-node.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #/bin/bash
          while true
          do
            export NUM=$(kubectl get nodes --kubeconfig=/etc/kubernetes/admin.conf | wc -l)
            if [ $NUM -gt 2 ];then
              /bin/touch /var/log/install-opebs.stamp
              break
            fi
          done
    - path: /root/install-openebs.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #/bin/bash
          curl https://openebs.github.io/charts/openebs-operator.yaml -o /root/openebs-operator.yaml
          /bin/sleep 6
          kubectl apply -f /root/openebs-operator.yaml --kubeconfig=/etc/kubernetes/admin.conf
          /bin/sleep 6
          kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' --kubeconfig=/etc/kubernetes/admin.conf
 
    - path: /root/install-kubesphere.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #!/bin/sh
          
          curl https://github.com/kubesphere/ks-installer/releases/download/v3.3.1/kubesphere-installer.yaml -o /root/kubesphere-installer.yaml
          /bin/sleep 6
          sed -i '/      serviceAccountName: ks-installer/a\      securityContext:\n        runAsUser: 0\n        runAsGroup: 0\n        fsGroup: 0' /root/kubesphere-installer.yaml
          kubectl apply -f /root/kubesphere-installer.yaml --kubeconfig=/etc/kubernetes/admin.conf

    - path: /root/install-cluster-configuration.sh
      mode: 0644
      overwrite: true
      contents:
        inline: |
          #!/bin/sh
          
          curl https://github.com/kubesphere/ks-installer/releases/download/v3.3.1/cluster-configuration.yaml -o /root/cluster-configuration.yaml
          /bin/sleep 6
          kubectl apply -f /root/cluster-configuration.yaml --kubeconfig=/etc/kubernetes/admin.conf

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
        ExecStart=bash -c "sed -i '24aallow 192.168.122.0/24' /etc/chrony.conf"
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
        Restart=on-failure
        ExecStart=bash -c "curl https://docs.projectcalico.org/v3.19/manifests/calico.yaml -o /root/calico.yaml"
        ExecStart=/bin/sleep 6
        ExecStart=bash -c "sed -i 's#usr/libexec/#opt/libexec/#g' /root/calico.yaml"
        ExecStart=kubectl apply -f /root/calico.yaml --kubeconfig=/etc/kubernetes/admin.conf
        
        [Install]
        WantedBy=multi-user.target
          
    - name: detect-node.service
      enabled: true
      contents: |
          [Unit]
          Description=detect nodes
          Wants=install-cni-plugin.service
          After=install-cni-plugin.service
 
          [Service]
          ExecStart=sh /root/detect-node.sh
          Restart=always
          StartLimitInterval=0
          RestartSec=10
          [Install]
          WantedBy=multi-user.target

    - name: install-openebs.service
      enabled: true
      contents: |
          [Unit]
          Description=install openebs to creat LocalPV
          Wants=detect-node.service
          After=detect-node.service
 
          [Service]
          ExecStart=sh /root/install-openebs.sh
          Restart=always
          StartLimitInterval=0
          RestartSec=10

          [Install]
          WantedBy=multi-user.target
    - name: install-kubesphere.service
      enabled: true
      contents: |
          [Unit]
          Description=install kubesphere
          Wants=install-openebs.service
          After=install-openebs.service

          [Service]
          ExecStart=sh /root/install-kubesphere.sh
          Restart=always
          StartLimitInterval=0
          RestartSec=10

          [Install]
          WantedBy=multi-user.target
    - name: cluster-configuration.service
      enabled: true
      contents: |
          [Unit]
          Description=deploy cluster-configuration
          Wants=install-kubesphere.service
          After=install-kubesphere.service

          [Service]
          ExecStart=sh /root/install-cluster-configuration.sh
          Restart=always
          StartLimitInterval=0
          RestartSec=10

          [Install]
          WantedBy=multi-user.target

```

Example butane configuration file for Node:

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
          id=${NET_CARD}
          type=ethernet
          interface-name=${NET_CARD}
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

### Generating an Ignition file

To make it easier for users to read and write, Ignition files add a step of conversion: converting Butane configuration file (yaml format) to Ignition file (json format), and using the resulting Ignition file to bootstrap a new NestOS image.The command to convert the Butane configuration to the Ignition configuration:

```
podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < your_config.bu > transpiled_config.ign
```



## Build the KubeSphere

Using the Ignition file you configured in the previous section, run the following command to create a Master node for the k8s cluster.The vcpus, ram and disk parameters can be adjusted by yourself. For details, refer to the virt-install manual.

```
virt-install --name=${NAME} --vcpus=4 --ram=8192 --import --network=bridge=virbr0 --graphics=none --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_FILE_PATH}" --disk=size=40,backing_store=${NESTOS_RELEASE_QCOW2_PATH} --network=bridge=virbr1 --disk=size=40
```

After the Master node system is installed successfully, a series of environment configuration services will be launched in the background of the system.In these services,set-kernel-para.service will configure the kernel parameters, pull-images.service will pull the images needed for the cluster, disable-selinux. service will set the time synchronization, init-cluster.service will initialize the cluster, and install-cni-plugin.service will install the cni networking plugin.The entire cluster deployment process requires a wait of several minutes for images to be pulled.

You can see if all pods are running with the kubectl get pods -A command:

![](/docs/zh/graph/K8S容器化部署/k1.PNG)

On the Master node, view the token with the following command:

```
kubeadm token list
```

At the same time, we add the query token information to the ignition file of the Node, and use the ignition file to create the Node.Once the Node is created, you can check whether it has joined the cluster by running the kubectl get nodes command on the Master Node.

![](/docs/zh/graph/K8S容器化部署/k2.PNG)

Now, k8s has been successfully deployed.After the setup is completed, install-openebs.service on the Master node will install OpenEBS to create the LocalPV storage type and set it as the default storage type.Finally,install-kubesphere.service and cluster-configuration.service will complete KubeSphere deployment. You can check the installation logs by running: 
```
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f
```

Use kubectl get pod --all-namespaces to see if all pods are running in the namespace associated with KubeSphere. If it is running, check the console's port (30880 by default) with the following command:
```
kubectl get svc/ks-console -n kubesphere-system
```

Make sure port 30880 is open in the security group and the Web console is accessed via NodePort (IP:30880) using the default account and password (admin/P@88w0rd)
