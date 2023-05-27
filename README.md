# 📁面向表情动画生成的真实感渲染研究

存储了我的毕业设计项目，主要是基于Kajiya-Kay,Marschner,视差原理等分别实现头发，眼睛渲染后再与VOCA生成的人脸模型序列组合生成真实的表情动画视频。

## 结构介绍

![](http://cdn.coolchong.cn/语音驱动说话人表情渲染/Unity.png)

```
Project
├─Audios // 存储表情动画的音频
├─Editor // 插件存储
├─Materials //材质
├─meshes // 表情动画人脸模型序列
├─Models // 渲染后的模型
├─Scenes // 场景
├─Scripts // 表情动画播放脚本
├─Shaders // 渲染管线
└─Textures // 材质
    ├─Eye // 眼睛渲染所需材质
    ├─Kajiya_Kay // Kajiya-Kay毛发渲染模型所需材质
    ├─Marchner //Marschner毛发渲染模型所需材质
    └─Skin // 皮肤渲染所需材质
```

其中皮肤的渲染管线使用的是Unity的标准渲染管线，只是添加了pbr材质。

## 效果图

<img src="http://cdn.coolchong.cn/语音驱动说话人表情渲染/expressions.gif" style="zoom:200%;" />

表情动画模型序列的生成与人脸贴图均使用的是VOCA提供的项目，链接如下：

https://github.com/TimoBolkart/voca 表情动画模型序列生成

https://github.com/HavenFeng/photometric_optimization 根据图片生成VOCA所需的人脸贴图

要实现如上效果，需要将脚本Expressions.cs绑定到对应游戏对象上，同时播放时设置为点击开始，因此需要为游戏对象设置碰撞组件Box Collider。

**Master分支存储的是Assets文件夹，欲要直接查看项目，您可以在Project分支下载Unity压缩包文件，通过Assets->Import Package一键导入项目并在Main Scene中查看。祝您学习愉快😉！**





