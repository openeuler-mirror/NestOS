# nestos assembler

## nestos-assembler含义

nosa是一个构建环境，该环境包含一系列工具，可用来构建nestos，因此，nosa实现了在构建和测试操作系统的过程都是封装在一个容器中，且容器体积较大。nosa可以简单理解为是一个可以构建nestos的fedora系统，该系统集成了构建nestos所需的一些脚本、rpm包和工具。

## 构建nestos

### 构建原理

rpm-ostree可进行包/文件系统管理，该工作方式与git类似。nosa的构建模式是将ostree提交和磁盘镜像绑定在一起，首先rpm-ostree和ostree根据配置文件、软件包整合到文件系统中，最后部署到基础磁盘镜像当中。该方式也决定了系统可进行分层。

### 准备工作

nestos镜像的制作需要在特定的构建目录下进行，因此需进行以下准备

 - nestos-assembler 镜像
 - 构建目录（builds、src、cache、tmp），可通过命令 `nosa init` 生成

其中src是最重要的目录，其中包含构建镜像必需的各种配置文件，比如：

 - manifest.yaml：它主要包含镜像名称、rpm列表基本参数配置等，还支持`postprocess`进行任意更改
 - image.yaml: 包含对磁盘镜像的参数配置，如压缩方式等
 - overlay.d： 可嵌入到系统内，包含配置文件、service、脚本等，`overlay.d/`中的每个子目录都会顺序添加到OSTree提交中，每个子目录是一次commit，且使用数字前缀命名目录

![enter description here](/docs/graph/nestos-assembler/fetch1.png)

![enter description here](/docs/graph/nestos-assembler/fetch2.png)

### 构建nestos

|  name   |   Description  |
| --- | --- |
| nosa init | clone构建目录 |
|   nosa clean  |  删除历史构建(builds、tmp)   |
|   nosa fetch  |  下载所需rpm包   |
|   nosa build  |   通过下载的rpm包构建ostree和qemu镜像  |
| nosa buildextend-metal | 构建metal镜像 |
| nosa buildextend-metal4k | 构建metal4k镜像 |
| nosa buildextend-live | 构建iso镜像 |
| nosa run | 运行qemu镜像 |
## nestos-assembler结构
```
 _________________________
|                         |
| NestOS Config           |
|  - rpm-ostree manifests |___
|  - nestos-pool.repo     |   \
|  - misc other things    |    \
|_________________________|     \
                                 \
                                  \     _____________________________
 _________________________         \   |                             |       ___________________________
|                         |         \  | nestos-assembler container: |      |                           |
|          RPMS           | ---------> |  - Fedora35 Base            | ---> | OSTree commits and images |
|_________________________|        /   |  - build scripts installed  |      |___________________________|
                                  /    |_____________________________|
                                 /
 _________________________      /
|                         |    /
| nestos Assembler        |___/
|  - build scripts        |
|_________________________|

```