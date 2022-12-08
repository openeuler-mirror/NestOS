# K8S+iSulad 搭建

**以下步骤在master节点和node节点均需执行**，本教程以master为例

## 开始之前

需准备如下内容
1.NestOS-LTS-live.x86_64.iso
2.一台主机用作master，一台主机用作node

## 组件下载

编辑源文件,添加k8s的阿里云源

```
vi /etc/yum.repos.d/openEuler.repo
```

添加如下内容

```
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
```

下载k8s组件以及同步系统时间所用组件

```
rpm-ostree install kubelet kubeadm kubectl ntp ntpdate wget
```

![image-20211014203239831](/docs/zh/graph/K8S+iSulad搭建/image-20211014203239831.png)

重启生效

```
systemctl reboot
```

选择正确的分支

![image-20211014203252726](/docs/zh/graph/K8S+iSulad搭建/image-20211014203252726.png)

查看软件包是否已安装

```
rpm -qa | grep kube
```

![image-20211014203302042](/docs/zh/graph/K8S+iSulad搭建/image-20211014203302042.png)

## 配置环境

### 修改主机名，以master为例

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

```
关闭swap分区，防火墙,selinux
```

NestOS默认无swap分区，默认关闭防火墙
关闭selinux如下

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

查看k8s需要的系统镜像，需注意pause的版本号

```
kubeadm config images list
```

![image-20211014203312883](/docs/zh/graph/K8S+iSulad搭建/image-20211014203312883.png)

修改daemon配置文件

```
vi /etc/isulad/daemon.json
```

```
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
systemctl enable kubelet
```

**以上为master，node节点均需执行的操作。**

## master节点初始化

**该部分仅master节点执行。**
初始化，在这一步会拉取镜像，需等待一小段时间。也可在该步骤之前手动拉取镜像。

```
kubeadm init --kubernetes-version=1.22.2 --apiserver-advertise-
address=192.168.237.133 --cri-socket=/var/run/isulad.sock --image-repository
registry.aliyuncs.com/google_containers --service-cidr=10.10.0.0/16 --pod-
network-cidr=10.122.0.0/16
```

```
##关于初始化参数的解释说明##
kubernetes-version 为当前安装的版本
apiserver-advertise-address 为master节点ip
cri-socket 指定引擎为isulad
image-repository 指定镜像源为阿里云,可省去修改tag的步骤
service-cidr 指定service分配的ip段
pod-network-cidr 指定pod分配的ip段
```

初始化成功后可看到如下界面:

![image-20211014203323220](/docs/zh/graph/K8S+iSulad搭建/image-20211014203323220.png)

复制最后两行内容方便后续node节点加入使用

```
kubeadm join 192.168.237.133:6443 --token j7kufw.yl1gte0v9qgxjzjw --discovery-
token-ca-cert-hash
sha256:73d337f5edd79dd4db997d98d329bd98020b712f8d7833c33a85d8fe44d0a4f5 --cri-
socket=/var/run/isulad.sock
```

**注意**:添加--cri-socket=/var/run/isulad.sock以使用isulad为容器引擎
查看下载好的镜像

```
isula images
```

![image-20211014203329239](/docs/zh/graph/K8S+iSulad搭建/image-20211014203329239.png)

按照初始化成功所提示，配置集群

```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
source /etc/profile
```

查看健康状态

```
kubectl get cs
```

![image-20211014203335591](/docs/zh/graph/K8S+iSulad搭建/image-20211014203335591.png)

可以看到controller-manager,scheduler状态为unhealthy，解决方法如下:
编辑相关配置文件

```
vi /etc/kubernetes/manifests/kube-controller-manager.yaml
```

```
注释如下内容:
--port=0
修改hostpath:
将所有/usr/libexec/kubernetes/kubelet-plugins/volume/exec 修改为/opt/libexec/...
```

```
vi /etc/kubernetes/manifests/kube-scheduler.yaml
```

```
注释如下内容:
--port=0
```

等待片刻后，再次查看健康状态

![image-20211014203341778](/docs/zh/graph/K8S+iSulad搭建/image-20211014203341778.png)

## 配置网络插件

仅需要在master节点配置网络插件，但是要在**所有节点**提前拉取镜像,拉取镜像指令如下。

```
isula pull calico/node:v3.19.3
isula pull calico/cni:v3.19.3
isula pull calico/kube-controllers:v3.19.3
isula pull calico/pod2daemon-flexvol:v3.19.3
```

**以下步骤仅在master节点执行**
获取配置文件

```
wget https://docs.projectcalico.org/v3.19/manifests/calico.yaml
```

编辑calico.yaml 修改所有/usr/libexec/... 为 /opt/libexec/...
然后执行如下命令完成calico的安装:

```
kubectl apply -f calico.yaml
```

通过kubectl get pod -n kube-system查看calico是否安装成功
通过kubectl get pod -n kube-system查看是否所有pod状态都为running

![image-20211014203349296](/docs/zh/graph/K8S+iSulad搭建/image-20211014203349296.png)

## node节点加入集群

在node节点执行如下指令，将node节点加入集群

```
kubeadm join 192.168.237.133:6443 --token j7kufw.yl1gte0v9qgxjzjw --discovery-
token-ca-cert-hash
sha256:73d337f5edd79dd4db997d98d329bd98020b712f8d7833c33a85d8fe44d0a4f5 --cri-
socket=/var/run/isulad.sock
```

通过kubectl get node 查看master，node节点状态是否为ready

![image-20211014203355103](/docs/zh/graph/K8S+iSulad搭建/image-20211014203355103.png)

再次查看pod

![image-20211014203400852](/docs/zh/graph/K8S+iSulad搭建/image-20211014203400852.png)

至此，k8s部署成功。
