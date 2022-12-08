# 	Deploy the kubernetes cluster based on NestOS

​		

## Overall Solution

Kubernetes is a choreography management tool for portable containers. The purpose of this guide is to provide a NestOS solution for rapid containerized deployment of kubernetes. The solution uses the virtualization platform to create multiple NestOS nodes as the validation environment for deploying kubernetes, and pre-configuates the required environment for kubernetes into a yaml file by writing the Ignition file. After the NestOS operating system is installed, resources required for kubernetes are deployed and nodes are created. You can also use this document and the NestOS bare-metal installation documentation to deploy kubernetes in a bare-metal environment.

- Version Information:

  - NestOS version：22.09

  - Kubernetes version：v1.23.10

  - isulad version：2.0.16

- Installation Requirements
  - 2GB or more RAM per machine
  -  CPU2 core or higher
  -  All machines in the cluster are communicating properly
  - The host name cannot be the same on the node
  - Access the Internet and pull up mirrors
  - Disable swap partition
  - Close selinux
- Deployment Contents
  - NestOS image integrates binary files such as isulad, kubeadm, kubelet, and kubectl
  - Deploy the kubernetes Master node
  - Deploy the container network plug-in
  - Deploy the kubernetes Node and add it to the kubernetes cluster

## Configure the Kubernetes node

NestOS implements node batch configuration through the Ignition file mechanism. This section describes the Ignition file generation method and provides an example of the Ignition configuration when deploying kubernetes in a container. The system configuration of the node is as follows:

| Configuration Items          | Instructions                                                 |
| ---------------------------- | ------------------------------------------------------------ |
| passwd                       | Configure node login users and access authentication information |
| hostname                     | Configure the node hostname                                  |
| The time zone                | Configure the default time zone for the node                 |
| Kernel parameters            | The deployment environment requires some kernel parameters to be enabled |
| Close selinux                | selinux needs to be closed                                   |
| Setting Time Synchronization | Synchronize the cluster time through the chronyd service     |

### Generating a login Password

To access the NestOS in password mode, run the following command to generate ${PASSWORD_HASH} for the ignition file configuration:

```
openssl passwd -1 -salt yoursalt
```

### Generate an ssh key pair

To access the NestOS in ssh public key mode, run the following command to generate the ssh key pair:

```
ssh-keygen -N '' -f /root/.ssh/id_rsa
```

View the public key file id_rsa.pub to obtain the ssh public key information for Ignition file configuration:

```
cat /root/.ssh/id_rsa.pub
```

### Write the butane configuration file

The following fields need to be configured based on the actual deployment situation. The above section provides the generation method for some fields:

- ${PASSWORD_HASH}：Login Password
- ${SSH-RSA}：Public key
- ${MASTER_NAME}：Master node hostname
- ${MASTER_IP}：Master node IP
- ${MASTER_SEGMENT}：Master node Network segment
- ${NODE_NAME}：hostname of the work node
- ${NODE_IP}：IP of the work node
- ${GATEWAY}：gateway
- ${service-cidr}：service ip address segment
- ${pod-network-cidr}：pod ip address segment
- ${image-repository}：mirror address
- ${token}：token

Example of the butane configuration file for the master node:

```yaml
variant: fcos
version: 1.1.0
##passwd
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
      ##ssh
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

Example of a Node butane configuration file:

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

### Generate Ignition files

The Butane configuration is converted to the Ignition configuration command:

```
podman run --interactive --rm quay.io/coreos/butane:release --pretty --strict < your_config.bu > transpiled_config.ign
```



## Create the Kubernetes cluster

Using the Ignition file configured in the previous section, create the Master node of the k8s cluster with adjustable vcpus, ram, and disk parameters (see the virt-install manual for details) by executing the following command.

```
virt-install --name=${NAME} --vcpus=4 --ram=8192 --import --network=bridge=virbr0 --graphics=none --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${IGNITION_FILE_PATH}" --disk=size=40,backing_store=${NESTOS_RELEASE_QCOW2_PATH} --network=bridge=virbr1 --disk=size=40
```

After the Master node is successfully installed, a series of environment configuration services will be started in the background of the system. Among them, set-kernel-para.service will configure kernel parameters, and pull-images.service will pull images required by the cluster. disable-selinux.service disables selinux, set-time-sync.service sets time synchronization, and init-cluster.service initializes the cluster. install-cni-plugin.service installs the cni network plug-in. During the cluster deployment process, you need to wait several minutes because the image is to be pulled.

Run the kubectl get pods -A command to check whether all Pods are in the running state:

![](/docs/en/graph/kubernetes/k1.PNG)

To view the token on the Master node, run the following command:

```
kubeadm token list
```

Add the token information to the ignition file of the work node, and use that ignition file to create work nodes. After a work nodes are created, check whether it is added to the cluster.

![](/docs/en/graph/kubernetes/k2.PNG)

Kubernetes is deployed successfully
