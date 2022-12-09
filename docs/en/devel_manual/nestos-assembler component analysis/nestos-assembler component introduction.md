# nestos assembler

## What is nestos-assembler

Nosa is a build environment that contains a set of tools for building nestos. As a result, nosa enables the process of building and testing an operating system to be encapsulated in a large container. It can be simple to thought nosa as a fedora system for building nestos, which integrates some scripts, rpm packages, and tools to build nestos. 

## Build nestos

### Principle

Rpm-ostree allows for managing package/file system, which is similar to git.Nosa's build pattern is to bind the ostree commit to the disk image. Firstly, rpm-ostree and ostree are integrated into the file system based on the configuration file and software package, that finally deployed into the underlying disk image. This approach also determines that the system can be layered.

### Prepare

The nestos image needs to be created in a specific build directory. Therefore, you need to make the following preparations:

 - nestos-assembler image
 - Build directories（builds、src、cache、tmp），which can be generate by `nosa init`.

src is the most important directory and contains the various configuration files necessary to build the image, such as:

 - manifest.yaml: It mainly contains the image name, rpm list basic parameter configuration, and also supports 'postprocess' to make any changes.
 - image.yaml: It contains the parameter settings for images, such as the compression mode.
 - overlay.d: It can be embedded into the system, containing configuration files, services, scripts, etc. Each subdirectory in 'overlay.d/' is sequentially added to the OSTree commit. Each subdirectory is a commit, and the directory is named with a numeric prefix.

![enter description here](/docs/en/graph/nestos-assembler/fetch1.png)

![enter description here](/docs/en/graph/nestos-assembler/fetch2.png)

### Build nestos

|  name   |   Description  |
| --- | --- |
| nosa init | clone build directory |
|   nosa clean  |  delete the history (builds、tmp)   |
|   nosa fetch  |  download the required rpm package   |
|   nosa build  |  build ostree and qemu images from downloaded rpm packages  |
| nosa buildextend-metal | build metal image |
| nosa buildextend-metal4k | build metal4k image |
| nosa buildextend-live | build iso image |
| nosa run | run qemu image |
## nestos-assembler structure
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