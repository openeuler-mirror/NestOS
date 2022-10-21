# 基于NestOS通过RKE2部署Kubernetes集群



## 前言

Rancher是一个Kubernetes管理工具，提供了管理生产中的容器所需的整体软件堆栈。Rancher用户可以选择使用Rancher Kubernetes Engine（RKE）或者docker在单节点上安装Rancher Server的方式创建Kubernetes集群，以及可以导入和管理现有的Kubernetes集群。

## 环境描述

本指南以虚拟机平台创建多个NestOS节点作为部署Kubernetes验证环境。

- 版本信息：

  - NestOS版本：22.09
  - RKE2版本：v1.24.6-rke2r1
  - Kubernetes版本：v1.24.6
  - Rancher：v2.6.9
  - Helm：1.7.1
- 安装要求：

  - 每台机器2GB或更多的RAM
  - CPU2核心及以上
  - 集群中所有机器之间网络互通
  - 每个节点有不同的主机名
  - 可以访问外网
  - 禁止swap分区
  - 关闭selinux


- 节点信息
  - rke2-node01 Server 节点（master、etcd）
  - rke2-node02 agent 节点 （worker）

### 节点配置

NestOS通过Ignition文件机制实现节点的批量配置，本章节提供了NestOS节点环境配置的示例。butane配置文件内容如下：

- ${PASSWORD_HASH}：指定节点的登录密码
- ${SSH-RSA}：配置节点的公钥信息
- ${MASTER_NAME}：配置主节点的hostname
- ${MASTER_IP}：配置主节点的IP
- ${NODE_NAME}：配置node节点的hostname
- ${NODE_IP}：配置node节点的IP
- ${GATEWAY}：配置节点网关

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
  files:
    - path: /etc/hostname
      mode: 0644
      contents:
        inline: k8s-master
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
  links:
    - path: /etc/localtime
      target: ../usr/share/zoneinfo/Asia/Shanghai
systemd:
  units:
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

```

### 部署RKE2 Kubernetes集群

#### RKE2 server节点安装

RKE2使用install.sh脚本进行安装：

1. 运行安装程序，安装指定版本的rke2，vx.y.z为rke2版本号

   ```
   curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vx.y.z sh -
   ```

   或者使用以下方法加速安装

   ```
   curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/rke2/install.sh | INSTALL_RKE2_MIRROR=cn INSTALL_RKE2_VERSION=vx.y.z sh -
   ```

2. 启用rke2-server服务

   ```
   systemctl enable rke2-server.service
   ```

3. 启动服务

   ```
   systemctl start rke2-server.service
   ```

   查看安装过程日志

   ```
   journalctl -u rke2-server -f
   ```

**运行安装程序后：**

- 安装rke2-server服务
- 安装kubectl、crictl和ctr，安装路径/var/lib/rancher/rke2/bin/
- 安装清理脚本rke2-killall.sh和rke2-uninstall.sh，安装路径/usr/local/bin/rke2
- 写入kubeconfig文件，写入路径/etc/rancher/rke2/rke2.yaml
- 创建注册其他server或agent节点的令牌，创建路径/var/lib/rancher/rke2/server/node-token

**备注**：如果需要添加额外的server节点，则总数必须为奇数，以用于维持选举数。

#### RKE2 agent节点安装

1. 运行安装程序

   ```
   curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
   ```

   或使用以下方法加速安装

   ```
   curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/rke2/install.sh | INSTALL_RKE2_MIRROR=cn INSTALL_RKE2_VERSION=vx.y.z INSTALL_RKE2_TYPE="agent" sh -
   ```

   此命令将在机器上安装rke2-agent服务和rke2二进制文件

2. 启用rke2-agent服务

   ```
   systemctl enable rke2-agent.service
   ```

3. 配置rke2-agent服务

   ```
   mkdir -p /etc/rancher/rke2/
   vi /etc/rancher/rke2/config.yaml
   ```

   config.yaml需填写Server节点的IP地址和token信息

   ```
   server: https://<server>:9345
   token: <token from server node>
   ```

   备注：rke2 server进程通过端口9345监听新节点的注册。正常情况下，kubernetes API仍可在6443上使用

4. 启动服务

   ```
   systemctl start rke2-agent.service
   ```

   查看安装过程日志

   ```
   journalctl -u rke2-agent -f
   ```

### 访问集群

利用/etc/rancher/rke2/rke2.yaml文件配置对Kubernetes集群的访问，可以选择以下两种方式。

利用KUBECONFIG的环境变量：

```
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get pods --all-namespaces
```

或者在命令中指定kubeconfig文件的位置：

```
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods --all-namespaces
```

查看是否所有pod状态都为running：

![](/docs/graph/rancher/rke2-1.PNG)

查看Node节点是否加入到了集群中：

![](/docs/graph/rancher/rke2-2.PNG)

RKE2默认使用containerd作为Runtime，如果需要查询主机上运行的容器，可以使用以下命令：

```
crictl --config /var/lib/rancher/rke2/agent/etc/crictl.yaml ps
```

#### 使用kubectl从外部访问集群

将/etc/rancher/rke2/rke2.yaml复制到位于集群外的机器上，作为~/.kube/config。然后将配置文件中的127.0.0.1替换为RKE2服务器的IP或主机名，这样kubectl就可以管理RKE2集群了。

至此以RKE2方式部署Kubernetes完成。

### 安装Rancher

在此章节，将Rancher部署在Kubernetes集群中。其中，Helm为Kubernetes的包管理器。

1、安装helm

```
curl -O https://get.helm.sh/helm-v3.10.0-linux-amd64.tar.gz
tar zxvf helm-v3.10.0-linux-amd64.tar.gz
mv ./linux-amd64/helm	/usr/local/bin/helm
helm version
```

2、添加Rancher helm repo源

```
helm repo add rancher-latest http://rancher-mirror.oss-cn-beijing.aliyuncs.com/server-charts/latest                               

#此处推荐使用为国内源地址，国外地址使用https://releases.rancher.com/server-charts/<CHART_REPO>
```

3、为Rancher创建命名空间

定义一个Kubernetes命名空间，用于安装由Chart创建的资源。这个命名空间名称为cattle-system：

```
kubectl create namespace cattle-system
```

4、选择SSL配置

这里使用Rancher生成的TLS证书，需要在集群中安装cert-manager：

```
#安装CRD
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

#添加Jetstack Helm仓库
helm repo add jetstack https://charts.jetstack.io

#更新本地Helm Chart仓库缓存
helm repo update

#安装cert-manager Helm Chart
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1
```

5、安装完cert-manager后，通过检查 cert-manager 命名空间中正在运行的 Pod 来验证它是否已正确部署：

```
kubectl get pods --namespace cert-manager

NAME                                       READY   STATUS    RESTARTS      AGE
cert-manager-646c67487-trzrc               1/1     Running   0             16h
cert-manager-cainjector-7cb8669d6b-f9pd9   1/1     Running   1 (13h ago)   16h
cert-manager-webhook-696c5db7ff-l6nkq      1/1     Running   0             16h

```

6、根据Rancher生成的证书，通过Helm安装Rancher

- hostname：设置为解析到你的负载均衡器的DNS名称

- bootstrapPassword：登录密码
- 如果需要安装指定的Rancher版本，使用--version

```
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.my.org \
  --set bootstrapPassword=admin \
```

7、验证Rancher Server是否部署成功

```
kubectl -n cattle-system rollout status deploy/rancher

deployment "rancher" successfully rolled out
```

```
kubectl -n cattle-system get deploy rancher
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
rancher   3/3     3            3           16h
```

现在Rancher Server已经可以正常运行了，安装完成。可以在浏览器中进行rancher登录访问了。

