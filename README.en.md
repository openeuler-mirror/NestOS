
#### In the constantly evolving cloud native world, containerization and virtualization technologies have become key components of modern application delivery and management. To meet this growing demand, we have launched two new versions based on NestOS-22.03-LTS-SP2, NestOS For Container and NestOS For Virt, focusing on providing the best container hosting and virtualization solutions. NestOS-22.03-LTS-SP4-20240628 version has been released. Welcome all developers to visit the [official NestOS website]( https://nestos.openeuler.org/ ) to download and experience it.

## 1. NestOS For Container
**NestOS for Container (NFC)** integrates rpm-ostree support, ignition configuration, and other technologies. It adopts a dual-root file system and  the design of atomic updates, and uses nestos-assembler to quickly integrate and build. It is also adapted to platforms such as K8S and openStack to optimize the noise floor of container operation, so that the system has the ability to build clusters very conveniently, and can run large-scale containerized workloads more securely.

![image-20211015170943884](docs/zh/graph/README/image-20211015170943884.png)


### 1.1 NFC-qucik start
[Deploying on Virtualization Platforms - VMware](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/%E5%BF%AB%E9%80%9F%E5%BC%80%E5%A7%8B.md)

### 1.2 NFC-application guide
①.  [Rpm-ostree usage](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/rpm-ostree%E4%BD%BF%E7%94%A8.md)
②.  [Zincati automatic update](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/zincati%E8%87%AA%E5%8A%A8%E6%9B%B4%E6%96%B0%E4%BD%BF%E7%94%A8.md)
③.  [NestOS customization](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/%E5%AE%9A%E5%88%B6NestOS.md)
④.  [Example of ignition configuration](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/ignition%E9%85%8D%E7%BD%AE.md) 
⑤.  [Container image update usage](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/%E5%AE%B9%E5%99%A8%E9%95%9C%E5%83%8F%E6%9B%B4%E6%96%B0%E4%BD%BF%E7%94%A8.md) 
⑥.  [Detailed explanation of more functional features](https://gitee.com/openeuler/NestOS/blob/master/docs/zh/usr_manual/%E5%8A%9F%E8%83%BD%E7%89%B9%E6%80%A7%E6%8F%8F%E8%BF%B0.md)

## 2. NestOS For Virt
**NestOS For Virt (NFV)** is a customized version designed for virtualization scenarios, pre-installed with virtualization key components. The goal is that users can easily create and manage virtual machines that provide superior virtualization performance whether working in development, test, or production environments, while running a variety of workloads on high-performance virtual machines for resource isolation and security.

Whether you're running cloud-native applications, virtualized environments, or both, NFC and NFV are the perfect choice. They provide stability, performance, and security to meet the requirements of modern data centers and cloud environments.

## 3. NestOS features

### 3.1 Nestos Kubernetes Deployer
**The Nestos Kubernetes Deployer (NKD)** is container cloud deployment and O&M tool dedicated to NFC. NKD is a solution for deploying Kubernetes clusters based on NestOS and consistent O&M with container cloud services and cloud base OS. The goal is to simplify the process of deploying and upgrading clusters by providing services such as deployment, updates, and configuration management of cluster infrastructure, including operating systems and Kubernetes infrastructure components, outside the cluster.

### 3.2 PilotGo
PilotGo is a plug-in O&M management platform incubated by Kylinsoft in the openEuler community. Based on the features and best practices of the NestOS platform, PilotGo brings customized O&M management functions and new architecture-aware plug-in features to the NestOS platform.

### 3.3 x2NestOS
x2nestos is a quick and easy deployment tool that converts a general operating system to an NFC version. The NFV version is integrated by default, and can also be used with other general Linux operating systems managed by yum or apt mainstream package managers. Based on the kexec dynamic kernel loading feature, the tool can skip the boot stage to complete the deployment of the operating system, effectively reducing the difficulty and cost of converting existing clusters to NFC.

### 3.4 Customize images
NFC, as a container cloud base operating system based on the idea of immutable infrastructure, distributes and updates the file system as a whole.This solution has brought huge improvements in operation and security. However, in the actual production environment, the officially released version is often difficult to meet the needs of users, so more convenient customization means are required. NFC integrates the feature of ostree native container , which allows users in container cloud scenarios to easily build custom images by writing a ContainerFile (Dockerfile) file using the familiar technology stack, which can be used for custom integration components or subsequent upgrade and maintenance.

### 3.5 Rubik: mix online and offline business
Rubik is a container hybrid engine that adapts to single-node computing power tuning and quality of service assurance. NFC has pre-enabled the kernel features of rubik( related to mix online and offline business), and supports the overall solution based on the rubik container hybrid engine. This solution greatly improves the resource utilization of container cloud scenarios while ensuring the quality of service of key services by reasonably scheduling and isolating resources.

### 3.6 Kernel feature enhancements
We maintain nestos-kernel independently and develop it based on the openEuler-22.03-sp2 kernel version. In this process, we focus on improving the kernel features such as mm, CPU, cgroup, etc., to create features that are different from openEuler kernel and have better optimized performance.


#### For more details, please visit the [official NestOS website](https://nestos.openeuler.org/)

## 4. Container performance testing


Use NestOS For Container-22.03-LTS-SP2.20230928 to compare the performance of docker, podman, and iSulad container engines. The test results are as follows, showing that the performance of containers running in NFC is much better than that of traditional CentOS.


| operator(ms) | NestOS(Podman) | CentOS(Podman) | NestOS(iSulad) | CentOS(iSulad) | NestOS(Docker) | CentOS(Docker) |
| :----------: | :----: | :----: | :----: | :-------: | :-------: | :-------: |
|  100*creat   |  3436  | 6761  |  858  |   882    |   1375    |   2919    |
|  100*start   |  5496  |  10130  |  1885  |   2123    |   7397    |   18400    |
|   100*stop   |  2516  |  2532  |  457   |   497   |   1052    |   465    |
|    100*rm    |  2971  |  3141  |  501   |   566    |   1116    |   6838    |


## 5. Main Contributor

|   Gitee ID    |   company  |          email           |
| :-----------: | :------: | :---------------------: |
|  @duyiwei7w   | KylinSoft |   duyiwei@kylinos.cn    |
|  @ccdxx       | KylinSoft |   chendexi@kylinos.cn    |
|    @shanph    | KylinSoft |  lishanfeng@kylinos.cn  |
| @wangyueliang | KylinSoft | wangyueliang@kylinos.cn |
| @jianli-97    | KylinSoft |  lijian2@kylinos.cn     |
| @duguhaotian  |   Huawei   |   liuhao27@huawei.com   |

## 6. Honor Contributor

Thank you to the following original contributors for their contributions to the NestOS project and openEuler community:

|   Gitee ID    |   company  |          email           |
| :-----------: | :------: | :---------------------: |
| @fu-shanqing  | KylinSoft |  fushanqing@kylinos.cn  |
|  @ningjinnj   | KylinSoft |   ningjin@kylinos.cn    |



Anyone who is interested in contributing to the project is welcome to participate.
