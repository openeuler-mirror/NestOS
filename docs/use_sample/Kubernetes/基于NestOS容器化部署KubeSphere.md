# 基于NestOS部署KubeSphere

##  整体方案

KubeSphere是在 Kubernetes之上构建的**以应用为中心**的**企业级分布式容器平台**，提供简单易用的操作界面以及向导式操作方式，在降低用户使用容器调度平台学习成本的同时，极大减轻开发、测试、运维的日常工作的复杂度，旨在解决 Kubernetes 本身存在的存储、网络、安全和易用性等痛点。本指南旨在提供NestOS容器化部署KubeSphere的解决方案。该方案以虚拟化平台创建多个NestOS节点作为部署Kubernetes的验证环境,搭建社区版的Kubernetes平台，并在 Kubernetes之上部署KubeSphere。裸金属环境也可以参考本文并结合NestOS裸金属安装文档完成KubeSphere部署。

- 版本信息：
  - NestOS镜像版本：22.09
  - 社区k8s版本：v1.20.2
  - isulad版本：2.0.16
  - KubeSphere版本：v3.3.1
- 安装要求
  - 每台机器4GB或更多的RAM
  - CPU2核心及以上
  - 集群中所有机器之间网络互通
  - 节点之中不可以有重复的主机名
  - 可以访问外网，需要拉取镜像
  - 禁止swap分区
  - 关闭selinux
- 部署内容
  - NestOS镜像以集成isulad和社区版kubeadm、kubelet、kubectl等二进制文件
  - 部署k8s Master节点
  - 部署容器网络插件
  - 部署k8s Node节点，将节点加入k8s集群中
  - 部署KubeSphere

## 开始之前

需准备如下内容 1.nestos-22.09.qcow2 2.一台主机用作master，一台主机用作node,以下步骤在master节点和node节点均需执行。

##  配置环境

修改主机名，以master为例

```
hostnamectl set-hostname k8s-master
sudo -i
```

编辑/etc/hosts

```
vi /etc/hosts
```

添加如下内容，ip为主机ip

```
192.168.237.133 k8s-master
192.168.237.135 k8s-node01
```

### 同步系统时间

```
ntpdate time.windows.com
systemctl enable ntpd
```

NestOS默认无swap分区，默认关闭防火墙 关闭selinux如下

```
vi /etc/sysconfig/selinux
修改为SELINUX=disabled
```

### 网络配置，开启相应的转发机制

创建配置文件

```
vi /etc/sysctl.d/k8s.conf
```

添加如下内容

```
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
```

使配置生效

```
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
```

## 配置iSula

修改daemon配置文件

```
vi /etc/isulad/daemon.json
##关于添加项的解释说明##
registry-mirrors 设置为"docker.io"
insecure-registries 设置为"rnd-dockerhub.huawei.com"
pod-sandbox-image 设置为"registry.aliyuncs.com/google_containers/pause:3.5"(使用阿
里云,pause版本可在上一步查看)
network-plugin 设置为"cni"。
cni-bin-dir 设置为"/opt/cni/bin";
cni-conf-dir 设置为"/etc/cni/net.d"
```

修改后的完整文件如下

```
{"group": "isula",
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
"rnd-dockerhub.huawei.com"
],
"pod-sandbox-image": "registry.aliyuncs.com/google_containers/pause:3.5",
"native.umask": "secure",
"network-plugin": "cni",
"cni-bin-dir": "/opt/cni/bin",
"cni-conf-dir": "/etc/cni/net.d",
"image-layer-check": false,
"use-decrypted-key": true,
"insecure-skip-verify-enforce": false
}
```

启动相关服务

```
systemctl restart isulad
systemctl enable isulad
```

## 添加kubelet系统服务

vim /etc/systemd/system/kubelet.service

```
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet#修改为kubelet二进制文件所在的路径
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
```

sudo mkdir -p /etc/systemd/system/kubelet.service.d

vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

```
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/boott
strap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, poo
pulating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a laa
st resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instee
ad. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
#修改为kubelet二进制文件所在的路径
ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $$
KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS

```

systemctl enable --now kubelet

**以上为master，node节点均需执行的操作。**

## 初始化master节点

配置master初始化yaml文件

vi kubeadm-config.yaml

```
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/isulad.sock"
  name: k8s-master
  kubeletExtraArgs:
    volume-plugin-dir: "/opt/libexec/kubernetes/kubelet-plugins/volume/exec/"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
controllerManager:
  extraArgs:
    flex-volume-plugin-dir: "/opt/libexec/kubernetes/kubelet-plugins/volume/exec/"
kubernetesVersion: v1.20.2
imageRepository: registry.aliyuncs.com/google_containers
controlPlaneEndpoint: "192.168.122.100:6443"#master的主机ip
networking:
  serviceSubnet: "10.96.0.0/16"
  podSubnet: "10.100.0.0/16"
  dnsDomain: "cluster.local"
dns:
  type: CoreDNS
  imageRepository: registry.aliyuncs.com/google_containers
  imageTag: v1.8.4
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
```

抓取镜像

kubeadm config images pull --config=kubeadm-config.yaml

初始化 Master 节点

kubeadm init --config=kubeadm-config.yaml --upload-certs

配置 kubectl

rm -rf /root/.kube/

mkdir /root/.kube/

cp -i /etc/kubernetes/admin.conf /root/.kube/config

chown $(id -u):$(id -g) /root/.kube/config

安装网络插件

```
wget https://docs.projectcalico.org/v3.19/manifests/calico.yaml
sed -i 's#usr/libexec/#opt/libexec/#g' /root/calico.yaml
sed -i 's/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/g' /root/calico.yaml
sed -i 's?#   value: "192.168.0.0/16"?  value: "10.100.0.0/16"?g' /root/calico.yaml
kubectl apply -f calico.yaml
```

coredns bug修复

coredns pod虽然是running 的状态，但是他是not ready，system:serviceaccount:kube-system:coredns 缺少权限

修复coredns角色权限

kubectl edit clusterrole system:coredns

在后面追加内容

```
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs:
  - list
  - watch
```

修改好后过一会再执行命令查看coredns pod

kubectl get pods -n kube-system 

## 初始化node节点

只在 master 节点执行

kubeadm token create --print-join-command

可获取kubeadm join 命令及参数，

```
kubeadm join 192.168.122.100:6443 --token en5jwd.pmkqlojjq1m22gmr   --discovery-token-ca-cert-hash sha256:3e55db5743e5858b8330e11cd4784e3039ef9ab66bc6ea327823b2021f70f045 
```

在命令结尾添加

```
--cri-socket=/var/run/isulad.sock
```

在node节点执行如下命令

```
kubeadm join 192.168.122.100:6443 --token en5jwd.pmkqlojjq1m22gmr   --discovery-token-ca-cert-hash sha256:3e55db5743e5858b8330e11cd4784e3039ef9ab66bc6ea327823b2021f70f045 --cri-socket=/var/run/isulad.sock
```

## 部署kubesphere

前提条件

集群已有默认的存储类型（StorageClass），若集群还没有准备存储请参考 安装 OpenEBS 创建 LocalPV 存储类型 用作开发测试环境，生产环境请确保集群配置了稳定的持久化存储。

安装 OpenEBS

```
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
```

如下将 `openebs-hostpath`设置为 **默认的 StorageClass**：

```text
$ kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
storageclass.storage.k8s.io/openebs-hostpath patched
```

至此，OpenEBS 的 LocalPV 已作为默认的存储类型创建成功。可以通过命令 kubectl get pod -n openebs来查看 OpenEBS 相关 Pod 的状态，若 Pod 的状态都是 running，则说明存储安装成功。

![](/docs/graph/kubesphere容器化部署/storage.png)

部署 KubeSphere

```
wget https://github.com/kubesphere/ks-installer/releases/download/v3.3.1/kubesphere-installer.yaml
```

修改kubesphere-installer.yaml，添加设置，使pod内的用户为root

![](/docs/graph/kubesphere容器化部署/root.png)

```
kubectl apply -f kubesphere-installer.yaml   
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.3.1/cluster-configuration.yaml
```

检查安装日志：

```
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f
```

使用 `kubectl get pod --all-namespaces` 查看所有 Pod 在 KubeSphere 相关的命名空间是否正常运行。如果是正常运行，请通过以下命令来检查控制台的端口（默认为 30880）：

```
kubectl get svc/ks-console -n kubesphere-system
```

确保在安全组中打开了 30880 端口，通过 NodePort (IP:30880) 使用默认帐户和密码 (admin/P@88w0rd) 访问 Web 控制台