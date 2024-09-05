
NestOS 发布目录结构调整
自2022年初首次正式发布以来，NestOS的发布流（stream metadata）管理逻辑一直较为简单，仅使用stable流进行发布。从24.03-LTS版本开始，我们对发布目录进行了规划改造，以适应更复杂的发布需求。

**发布策略**
发布流命名规则：使用openEuler社区发布的LTS版本号作为流名称。例如，openEuler-24.03-LTS系列对应的发布流为2403-LTS，后续发布的增强版本SP1、SP2等均沿用此发布流。
**nestos发布根目录**为: https://nestos.org.cn/NestOS-release

**以下是发布目录以及介绍**

```

/NestOS-release

	prod/#产品发布目录，根据流进行区分

		streams/

			2403-LTS/

				releases.json #①记录指定流下每一次构建不同架构的版本信息，用于自动更新

				builds/

					builds.json #②记录build信息，包括id和架构，来自构建目录

					24.03-LTS-20240903.0/

						release.json #③每个发布件的详细信息（所有架构）

						x86_64/

							meta.json # ④各种元数据，来自构建目录，包括发布件信息，差异包信息等

							nestos-qemu.x86_64.qcow2.gz # 发布件，用于用户下载

							...

						aarch64/

						...

					24.03-LTS-SP1-20241230.0/

						release.json

						x86_64/

							meta.json

							nestos-qemu.x86_64.qcow2.gz

							...

						aarch64/

						...

					...

			2603-LTS/

			...

	streams/ #⑤记录指定流的最新版本详细信息，包括各种类型镜像的位置、签名等

		2403-LTS.json

		2603-LTS.json

		...

	updates/ #⑥记录指定流的每一次的版本摘要信息，仅记录version，用于自动更新

		2403-LTS.json

		2603-LTS.json
```

以上是NestOS 2403版本的发布目录结构及其详细说明。希望这能帮助您更好地理解与使用我们的系统。


