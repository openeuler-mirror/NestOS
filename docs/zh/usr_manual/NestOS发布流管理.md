NestOS自首次正式发布以来，其发布流（stream metadata）一直延用Fedora CoreOS的管理策略，仅使用stable流进行发布，该方法较为单一，已无法满足NestOS版本发布现状。结合NestOS版本发布策略以及欧拉版本命名规则，从24.03-LTS版本开始，NestOS对发布流进行了规划改造，以适应更复杂的发布需求。

**发布策略**
发布流命名规则：使用openEuler社区发布的LTS版本号作为发布流名称,生命周期与openEuler保持一致。例如，openEuler-24.03-LTS系列对应的NestOS发布流为2403-LTS，且后续发布的增强版本SP1、SP2等均沿用此发布流。

**NestOS发布流目录**: https://nestos.org.cn/NestOS-release

**发布流目录结构与介绍**

```
/NestOS-release

	prod/#产品发布目录，根据流进行区分
		streams/
			2403-LTS/
				releases.json #记录指定流下每一次构建不同架构的版本信息，用于自动更新
				builds/
					builds.json #记录build信息，包括id和架构，来自构建目录
					24.03-LTS-20240903.0/
						release.json #每个发布件的详细信息（所有架构）
						x86_64/
							meta.json #各种元数据，来自构建目录，包括发布件信息，差异包信息等
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
			
	streams/ #记录指定流的最新版本详细信息，包括各种类型镜像的位置、签名等
		2403-LTS.json
		2603-LTS.json
		...

	updates/ #记录指定流的每一次的版本摘要信息，仅记录version，用于自动更新
		2403-LTS.json
		2603-LTS.json
```
