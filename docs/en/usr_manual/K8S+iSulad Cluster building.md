# K8S+iSulad Cluster building

The following steps must be performed on both the master and work nodes. This tutorial uses the master as an example

## Get ready

Be prepared

1. NestOS-LTS-live.x86_64.iso

2. One host serves as the master and the other as the node

## Component Download

Edit the source file and add k8s Aliyun repo

```
vi /etc/yum.repos.d/openEuler.repo
```

Add the following

```
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
```

Download the k8s components and the components used to synchronize system time

```
rpm-ostree install kubelet kubeadm kubectl ntp ntpdate wget
```

![image-20211014203239831](/docs/en/graph/K8S+iSulad/image-20211014203239831.png)

Restart to take effect

```
systemctl reboot
```

Choose the right branch

![image-20211014203252726](/docs/en/graph/K8S+iSulad/image-20211014203252726.png)

Check whether the software package is installed

```
rpm -qa | grep kube
```

![image-20211014203302042](/docs/en/graph/K8S+iSulad/image-20211014203302042.png)

## Configuring the Environment

### Change the host name, for example master node

```
hostnamectl set-hostname k8s-master
sudo -i
```

Edit /etc/hosts

```
vi /etc/hosts
```

Add the following information.

```
192.168.237.133 k8s-master
192.168.237.135 k8s-node01
```

### Synchronizing system time

```
ntpdate time.windows.com
systemctl enable ntpd
```

```
Disable swap, firewall, and selinux
```

NestOS does not have swap partition by default, and the firewall is disabled by default
Close selinux:

```
vi /etc/sysconfig/selinux
SELINUX=disabled
```

### Configure the network and enable the corresponding forwarding mechanism

Creating a Configuration File

```
vi /etc/sysctl.d/k8s.conf
```

Add the following

```
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
```

Make the configuration take effect

```
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
```

## Configuring iSula

To view the system image required by the k8s, note the version number of pause

```
kubeadm config images list
```

![image-20211014203312883](/docs/en/graph/K8S+iSulad/image-20211014203312883.png)

Example Modify the daemon configuration file

```
vi /etc/isulad/daemon.json
```

```
##An explanation of the added item##
registry-mirrors: set to"docker.io"
insecure-registries: set to "rnd-dockerhub.huawei.com"
pod-sandbox-image: set to "registry.aliyuncs.com/google_containers/pause:3.5"
network-plugin: set to "cni"。
cni-bin-dir: set to "/opt/cni/bin";
cni-conf-dir: set to "/etc/cni/net.d"
```

The complete modified file is as follows

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

Starting Related Services

```
systemctl restart isulad
systemctl enable isulad
systemctl enable kubelet
```

**The preceding operations are required for master and node.**

## The master node is initialized

**This section is performed only on the master node.**
Initialize, in which the image is pulled, and wait a short time. You can also manually pull an image before this step.

```
kubeadm init --kubernetes-version=1.22.2 --apiserver-advertise-
address=192.168.237.133 --cri-socket=/var/run/isulad.sock --image-repository
registry.aliyuncs.com/google_containers --service-cidr=10.10.0.0/16 --pod-
network-cidr=10.122.0.0/16
```

```
##An explanation of the initialization parameters##
kubernetes-version: Is the currently installed version
apiserver-advertise-address: master node ip
cri-socket: isulad
image-repository: Specifying the mirror source as Aliyun saves the step of modifying the tag
service-cidr: Specifies the ip address segment assigned by the service
pod-network-cidr: Specifies the ip address segment assigned by pod
```

After the initialization is successful, the following page is displayed:

![image-20211014203323220](/docs/en/graph/K8S+iSulad/image-20211014203323220.png)

Copy the last two lines for subsequent node additions

```
kubeadm join 192.168.237.133:6443 --token j7kufw.yl1gte0v9qgxjzjw --discovery-
token-ca-cert-hash
sha256:73d337f5edd79dd4db997d98d329bd98020b712f8d7833c33a85d8fe44d0a4f5 --cri-
socket=/var/run/isulad.sock
```

**Node**: add --cri-socket=/var/run/isulad.sock
View the downloaded image

```
isula images
```

![image-20211014203329239](/docs/en/graph/K8S+iSulad/image-20211014203329239.png)

Configure the cluster as prompted for successful initialization

```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
source /etc/profile
```

Viewing Health Status

```
kubectl get cs
```

![image-20211014203335591](/docs/en/graph/K8S+iSulad/image-20211014203335591.png)

The status of the controller-manager and scheduler is unhealthy. The solution is as follows:
Edit related configuration files

```
vi /etc/kubernetes/manifests/kube-controller-manager.yaml
```

```
Comment the following:
--port=0
Modify the hostpath:
/usr/libexec/kubernetes/kubelet-plugins/volume/exec -> /opt/libexec/...
```

```
vi /etc/kubernetes/manifests/kube-scheduler.yaml
```

```
Comment the following:
--port=0
```

Wait a moment and then check the health status again

![image-20211014203341778](/docs/en/graph/K8S+iSulad/image-20211014203341778.png)

## Configuring Network Plug-ins

Only the network plug-in needs to be configured on the master node, but the image should be pulled in advance on  all nodes. The image pulling instruction is as follows.

```
isula pull calico/node:v3.19.3
isula pull calico/cni:v3.19.3
isula pull calico/kube-controllers:v3.19.3
isula pull calico/pod2daemon-flexvol:v3.19.3
```

The following steps are performed only on the master node
Obtaining the Configuration File

```
wget https://docs.projectcalico.org/v3.19/manifests/calico.yaml
```

Edit calico.yaml to modify all /usr/libexec/... -> /opt/libexec /...
Then run the following command to install calico:

```
kubectl apply -f calico.yaml
```

Run the kubectl get pod -n kube-system command to check whether calico is installed successfully
Run the kubectl get pod-n kube-system command to check whether the status of all Pods is running

![image-20211014203349296](/docs/en/graph/K8S+iSulad/image-20211014203349296.png)

## node is added to a cluster

Run the following command on the work node to add the work node to the cluster

```
kubeadm join 192.168.237.133:6443 --token j7kufw.yl1gte0v9qgxjzjw --discovery-
token-ca-cert-hash
sha256:73d337f5edd79dd4db997d98d329bd98020b712f8d7833c33a85d8fe44d0a4f5 --cri-
socket=/var/run/isulad.sock
```

Run the kubectl get node command to check whether the status of the master node is ready

![image-20211014203355103](/docs/en/graph/K8S+iSulad/image-20211014203355103.png)

Look at the pod again

![image-20211014203400852](/docs/en/graph/K8S+iSulad/image-20211014203400852.png)

The k8s deployment is successful.
