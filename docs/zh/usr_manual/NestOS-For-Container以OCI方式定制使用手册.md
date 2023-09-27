## NestOS For Container以OCI方式定制使用手册


### 应用场景

&emsp;&emsp;NestOS for Containers，作为基于不可变基础设施思想的容器云底座操作系统，将文件系统作为一个整体进行分发和更新。这一方案在运维与安全方面带来了巨大的便利。然而，在实际生产环境中，官方发布的版本往往难以满足用户的需求。例如，用户可能希望在系统中默认集成自维护的关键基础组件，或者根据特定场景的需求对软件包进行进一步的裁剪，以减少系统的运行负担。因此，与通用操作系统相比，用户对NestOS有着更强烈和更频繁的定制需求。<br>

&emsp;&emsp;过往NestOS提供集成工具NestOS-assembler 用于满足用户自定义需求，但该方案较为复杂，需要用户准备rpm软件包源、修改相应构建配置信息，更重要的是与用户上层应用运维技术栈不符，学习成本很高。<br>

&emsp;&emsp;现NestOS For Container集成ostree native container特性，可使容器云场景用户利用熟悉的技术栈，只需编写一个ContainerFile(Dockerfile)文件，即可轻松构建定制版镜像，用于自定义集成组件或后续的升级维护工作。<br>

### 使用方式

#### 定制镜像
-------
##### 基本步骤
- 选择相同发布流与架构的NestOS容器镜像
- 编写Containerfile(Dockerfile)如下：
```dockerfile
FROM hub.oepkgs.net/nestos/nestos-test:22.03-LTS-SP2.20230922.0-aarch64
# 执行自定义构建步骤，例如安装软件或拷贝自构建组件
RUN rpm-ostree install strace && rm -rf /var/cache && ostree container commit
```
- 执行docker build或集成于CICD中构建相应镜像

##### 注意事项
- NestOS For Container 无yum/dnf包管理器，如需安装软件包可采用`rpm-ostree install`命令安装本地rpm包或软件源中提供软件
- 如有需求也可修改/etc/yum.repo.d/目录下软件源配置
- 每层有意义的构建命令末尾均需添加`&& ostree container commit`命令，从构建容器镜像最佳实践角度出发，建议尽可能减少RUN层的数量
- 构建过程中会对非/usr或/etc目录内容进行清理，因此通过容器镜像方式定制主要适用于软件包或组件更新，请勿通过此方式进行系统维护或配置变更（例如添加用户useradd）

#### 部署镜像
-------
##### 基本步骤
- 假设上述步骤构建容器镜像被推送为hub.oepkgs.net/nestos/nestos-test:demo-strace
- 在已部署NestOS For Container的环境中执行如下命令：
```shell
sudo rpm-ostree rebase  ostree-unverified-registry:hub.oepkgs.net/nestos/nestos-test:demo-strace --bypass-driver
```
- 重新引导后完成定制版本部署

##### 注意事项
- 在部署时，您可以添加 --bypass-driver 参数。这是因为 NestOS For Container 默认通过 zincati 服务来自动更新，但如果您计划长期使用容器镜像维护系统，请关闭 zincati 服务，此时无需添加该参数。
- 当您使用容器镜像方式部署后，rpm-ostree upgrade 默认会将更新源从ostree更新源地址更新为容器镜像地址。这会导致 zincati 服务的自动更新失效。之后，您可以在相同的tag下更新容器镜像，使用 rpm-ostree upgrade 可以检测远端镜像是否已经更新，如果有变更，它会拉取最新的镜像并完成部署。
	
#### 效果展示
- 部署过程

![部署过程](/docs/zh/graph/NestOS-For-Container以OCI方式定制/部署过程.png)

- 完成部署

![完成部署](/docs/zh/graph/NestOS-For-Container以OCI方式定制/完成部署.png)

### 原理介绍
//todo


### 参考资料
- https://ostreedev.github.io/ostree/
- https://coreos.github.io/rpm-ostree/container/
