# QtEasyTier

<div style="display: flex; gap: 0.5rem; justify-content: center; margin-top: 1rem;">
  <a href="https://gitee.com/myqfeng/qt-easy-tier/stargazers">
    <img src="https://gitee.com/myqfeng/qt-easy-tier/badge/star.svg?theme=dark" alt="star" />
  </a>
  <a href="https://gitee.com/myqfeng/qt-easy-tier/members">
    <img src="https://gitee.com/myqfeng/qt-easy-tier/badge/fork.svg?theme=dark" alt="fork" />
  </a>
  <a href="https://github.com/myqfeng/qt-easy-tier/stargazers">
    <img src="https://img.shields.io/github/stars/myqfeng/qt-easy-tier.svg" alt="star" />
  </a>
  <a href="https://github.com/myqfeng/qt-easy-tier">
    <img src="https://img.shields.io/github/forks/myqfeng/qt-easy-tier.svg" alt="star" />
  </a>
</div>

## 项目简介

QtEasyTier 是一个基于 Qt 框架开发的异地组网工具，用于创建和管理虚拟网络连接。
它提供了直观的图形界面，帮助用户轻松配置和管理虚拟网络，实现跨网络设备的安全通信。
程序后端为 EasyTier 核心，EasyTier 不同于传统工具，是一个去中心化的组网方案，无需依赖中心服务器，
每个节点平等对立，为用户提供更加安全，可靠，低成本的异地组网服务。

![QtEasyTier 界面展示](assets/qteasytier0.png)

## 项目特点

- 快速: 程序使用纯 Qt C++ 开发，无 Chromium 无 Webview，日常使用前端占用不超过50MB，运行高效快速。
- 美观: UI样式采用移植自 KDE 的 Breeze 样式，提供简洁美观现代化的用户界面。
- 简单: QtEasyTier 支持一键联机，小白也能轻松使用。
- 丰富：常规联机支持 EasyTier 大部分功能，按需定制你的虚拟网络。
- 安全: 后端为 EasyTier，一个简单、安全、去中心化的异地组网方案。

## 平台支持

- Windows 10/11
- 今后计划支持 Linux
- macOS（Apple Silicon / arm64，实验性支持，含 TUN 组网与一键联机）

## 快速上手

### 编译安装

*可以在Release处直接下载预编译的二进制文件*

#### 环境要求
- Qt 6（推荐6.10.1）
- CMake 3.5 或更高版本
- llvm-mingw 编译器，支持 C++ 20+（Windows）

#### 编译步骤
1. 克隆项目仓库
```bash
git clone https://gitee.com/myqfeng/qt-easy-tier.git
cd qt-easy-tier
```

2. 创建构建目录
```bash
mkdir build
cd build
```

3. 编译并安装项目
```bash
# 注意:构建QtEasyTier有两种模式
#   1. 正常模式, 配置保存在系统路径下
#   2. 便携模式, 配置保存在程序目录下, 构建命令加上 -DSAVE_CONF_IN_APP_DIR=true
#   ps: 为了不污染系统环境, 便携模式构建的程序禁用开机自启
cmake  ..
cmake --build . --config Release
cmake --install . --config Release
```

### macOS 安装（免 Apple 公证）

> macOS 构建为 Apple Silicon（arm64），未做 Apple 付费公证。新版 macOS（15 Sequoia / 26 Tahoe）对“下载来的”未公证程序拦截很严：直接双击 `.app` 会被 Gatekeeper 挡下（且系统已取消“右键打开”绕过），更关键的是——即使去掉隔离标记，需要管理员权限的 TUN 辅助程序 `QtEasyTierHelper` 仍会被系统拒绝运行（错误 `-423`），导致组网功能无法使用。

经实测，免公证的可靠安装方式是：用 `ditto` 把应用重建到**用户级** `~/Applications`（切断“下载来源”追踪），清除隔离属性，再在本机重新 ad-hoc 签名。**注意必须装到 `~/Applications` 而非系统级 `/Applications`** —— 实测装到 `/Applications` 会触发更严格的安全策略，使 helper 被拒、TUN 起不来；装到 `~/Applications` 则 GUI 与 helper 均正常，应用也照常出现在“启动台”。

下面任选其一安装：

**方式一 · 推荐 · 终端一键安装**

打开“终端”（启动台搜索 Terminal），粘贴执行：

```bash
curl -fsSL https://raw.githubusercontent.com/dwgx/qt-easy-tier/helper-on-latest/package/mac/web_install.sh | bash
```

脚本会自动下载 DMG、正确安装到 `~/Applications` 并打开。

**方式二 · 使用 DMG 内的安装脚本**

1. 从 Release 下载 DMG 并打开；
2. 打开“终端”，把 DMG 窗口里的 `install_qet.command` **拖进终端**回车执行
   （直接双击同样会被 Gatekeeper 拦，所以要在终端里运行）；
3. 按提示完成，程序装到 `~/Applications`。

首次使用 TUN 组网时会弹出一次管理员密码授权，属正常现象。

### 简单开始使用

#### 常规使用
- 双击 QtEasyTier.exe 启动应用程序
- 点击左下角加号创建网络配置
- 输入网络名称、用户名、密码等基本信息
- 配置高级选项（可选）
- 点击 "运行网络" 按钮即可启动网络连接

#### 一键联机
*QtEasyTier1.1.0新增功能*
- 启动程序后点击左下角一键联机按钮
- 房主勾选想添加服务器（可选）后点击运行按钮
- 将获得的房间号复制发给房客
- 房客选择相同服务器输入房间号并点击加入按钮即可加入网络

## 本程序依赖或使用的相关项目

### EasyTier

一个由 Rust 和 Tokio 驱动的简单、安全、去中心化的异地组网方案
- 官网：[https://easytier.cn/](https://easytier.cn/)

### Qt Framework

Qt 是一个跨平台的 C++ 应用程序开发框架，用于创建图形用户界面（GUI）和其他应用程序。
- 官网：[https://www.qt.io/](https://www.qt.io/)

### Breeze

Breeze 是 KDE Plasma 桌面环境的默认主题，本程序移植了其适用于 Qt 框架的样式库，为用户提供美观的界面。
- 官网：[https://kde.org/](https://kde.org/)

## 联系作者
- 项目地址：https://gitee.com/myqfeng/qt-easy-tier
- 问题反馈：欢迎提交 Issue 和 PR
- 交流方式：作者混迹于EasyTier支持3群，欢迎加入交流：957189589

## 许可证

本项目采用 GNU General Public License v3.0 (GPLv3) 许可证。详情请见 LICENSE 文件。

## 赞助与支持

软件开发不易, 您的赞助与支持是对本项目持续开发和维护的重要动力，也是对作者持续努力的认可。
如果您认为本项目对您有帮助，请考虑赞助本项目。

赞助方式：<br>
微信支付、支付宝

<p>
<img src="assets/wechat.webp" width="220">
<img src="assets/alipay.webp" width="220">
</p>

[点击前往赞助详情页面](https://qtet.070219.xyz/other/donate/)

