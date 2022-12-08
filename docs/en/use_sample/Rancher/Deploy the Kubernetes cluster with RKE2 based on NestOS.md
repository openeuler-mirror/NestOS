# Deploy the Kubernetes cluster with RKE2 based on NestOS



## Introduction

Rancher is a Kubernetes management tool that provides the overall software stack needed to manage containers in production. Rancher users can choose to create Kubernetes clusters using the Rancher Kubernetes Engine (RKE) or docker by installing Rancher Server on a single node, as well as importing and managing existing Kubernetes clusters.

## Environment

This guide uses the virtual machine platform to create multiple NestOS nodes as the deployment Kubernetes verification environment.

- Version information：

  - NestOS version：22.09
  - RKE2 version：v1.24.6-rke2r1
  - Kubernetes version：v1.24.6
  - Rancher：v2.6.9
  - Helm：1.7.1
- Installation Requirements:

  - 2GB or more RAM per machine
  - CPU2 core or higher
  - Network communication is normal between all machines
  - Each node has a different host name
  - Access the Internet normally
  - Disable swap partition
  - Disable selinux


- Node information
  - rke2-node01 Server node（master、etcd）
  - rke2-node02 agent node （worker）

### Node Configuration

NestOS uses the Ignition file mechanism to batch configure nodes. This section provides an example of how to configure the NestOS node environment. The butane configuration file is as follows:

- ${PASSWORD_HASH}：Login Password
- ${SSH-RSA}：Public key Information
- ${MASTER_NAME}：Set hostname for the master node
- ${MASTER_IP}：Configure the IP address of the master node
- ${NODE_NAME}：Set hostname for the work node
- ${NODE_IP}：Configure the IP address of the work node
- ${GATEWAY}：Gateway

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

### Deploy the RKE2 Kubernetes cluster

#### Install the RKE2 server node

RKE2 Use the install.sh script to install:

1. Run the installation program to install the specified version of rke2. 

   ```
   curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=vx.y.z sh -
   ```

   Or use the following methods to speed up the installation

   ```
   curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/rke2/install.sh | INSTALL_RKE2_MIRROR=cn INSTALL_RKE2_VERSION=vx.y.z sh -
   ```

2. Enable the rke2-server service

   ```
   systemctl enable rke2-server.service
   ```

3. start service

   ```
   systemctl start rke2-server.service
   ```

   View the installation process logs

   ```
   journalctl -u rke2-server -f
   ```

**After running：**

- Install the rke2-server service
- Install kubectl、crictl and ctr，install path /var/lib/rancher/rke2/bin/
- Installing the cleanup script rke2-killall.sh and rke2-uninstall.sh，install path /usr/local/bin/rke2
- Write kubeconfig，write path /etc/rancher/rke2/rke2.yaml
- Create a token to register another server or agent node，create path /var/lib/rancher/rke2/server/node-token

Note: If additional server nodes need to be added, the total number must be odd to maintain the election count.

#### Install RKE2 agent node

1. Run setup

   ```
   curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
   ```

   Or use the following methods to speed up the installation

   ```
   curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/rke2/install.sh | INSTALL_RKE2_MIRROR=cn INSTALL_RKE2_VERSION=vx.y.z INSTALL_RKE2_TYPE="agent" sh -
   ```

   This command installs the RKE2-agent service and the rke2 binary on the machine

2. enable rke2-agent service

   ```
   systemctl enable rke2-agent.service
   ```

3.  config rke2-agent service

   ```
   mkdir -p /etc/rancher/rke2/
   vi /etc/rancher/rke2/config.yaml
   ```

   config.yaml：Enter the IP address and token information of the Server node

   ```
   server: https://<server>:9345
   token: <token from server node>
   ```

   Note: The rke2 server process listens for new node registration through port 9345. Normally, the kubernetes API is still available on the 6443

4. start service

   ```
   systemctl start rke2-agent.service
   ```

   View the installation process logs

   ```
   journalctl -u rke2-agent -f
   ```

### Access Cluster

Using the/etc/rancher/rke2/rke2 yaml configuration file access to Kubernetes cluster, can choose the following two ways.

Using the KUBECONFIG environment variables:

```
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get pods --all-namespaces
```

Or specify the location of the kubeconfig file in the command:

```
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods --all-namespaces
```

Check whether all Pods are in the running state:

![](/docs/en/graph/rancher/rke2-1.PNG)

Check whether the Node is added to the cluster.

![](/docs/en/graph/rancher/rke2-2.PNG)

RKE2 uses containerd as the Runtime by default. To query the container running on the host, run the following command:

```
crictl --config /var/lib/rancher/rke2/agent/etc/crictl.yaml ps
```

#### Access the cluster externally using kubectl

The/etc/rancher/rke2 /rke2 yaml is copied to the outside of the cluster on the machine, as the ~ /. Kube/config. Then replace 127.0.0.1 in the configuration file with the IP or host name of the RKE2 server so that kubectl can manage the RKE2 cluster.

This completes the deployment of Kubernetes in RKE2 mode.

### Install rancher

In this section, the Rancher is deployed in a Kubernetes cluster. Helm is the package manager of Kubernetes.

1、Install helm

```
curl -O https://get.helm.sh/helm-v3.10.0-linux-amd64.tar.gz
tar zxvf helm-v3.10.0-linux-amd64.tar.gz
mv ./linux-amd64/helm	/usr/local/bin/helm
helm version
```

2、Add Rancher helm repo

```
helm repo add rancher-latest http://rancher-mirror.oss-cn-beijing.aliyuncs.com/server-charts/latest                               
# It is recommended to use the domestic source address and the foreign: addresshttps://releases.rancher.com/server-charts/<CHART_REPO>
```

3、Create namespace for Rancher

Define a Kubernetes namespace for installing the resources created by Chart. The name of this namespace is cattle-system:

```
kubectl create namespace cattle-system
```

4、Select SSL Configuration

Here, the TLS certificate generated by Rancher is used. You need to install cert-manager in the cluster:

```
#install CRD
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

#add Jetstack Helm
helm repo add jetstack https://charts.jetstack.io

#add Helm Chart
helm repo update

#install cert-manager Helm Chart
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1
```

5、After installing cert-manager, verify that it has been properly deployed by checking the Pod that is running in the cert-manager namespace:

```
kubectl get pods --namespace cert-manager

NAME                                       READY   STATUS    RESTARTS      AGE
cert-manager-646c67487-trzrc               1/1     Running   0             16h
cert-manager-cainjector-7cb8669d6b-f9pd9   1/1     Running   1 (13h ago)   16h
cert-manager-webhook-696c5db7ff-l6nkq      1/1     Running   0             16h

```

6、Install Rancher through Helm, according to the certificate Rancher generated

- hostname：Set the DNS name to resolve to your load balancer

- bootstrapPassword：Login Password
- If you need to install the specified Rancher version, use --version

```
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.my.org \
  --set bootstrapPassword=admin \
```

7、Verify that the Rancher Server has been successfully deployed

```
kubectl -n cattle-system rollout status deploy/rancher

deployment "rancher" successfully rolled out
```

```
kubectl -n cattle-system get deploy rancher
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
rancher   3/3     3            3           16h
```

Now that the Rancher Server is running properly, the installation is complete. rancher login access is now available in your browser.

