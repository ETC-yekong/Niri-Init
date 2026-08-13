# Niri-Init

基于 Arch Linux + [niri](https://github.com/YaLTeR/niri)（Wayland 合成器）的桌面环境一键安装与配置脚本集合。

## 目录结构

| 文件/目录 | 说明 |
| --- | --- |
| `install_software.sh` | 交互式常用软件与系统组件安装脚本 |
| `niri_init.sh` | niri 桌面环境一键部署脚本（v2.0） |
| `niri_init` | 供 AI/开发者参考的部署需求文档（非可执行脚本） |
| `kvm_intel.conf` | Intel KVM 嵌套虚拟化内核模块配置 |
| `starship.toml` | starship 终端提示符配置 |
| `fcitx5/` | 中文输入法（Rime）配置，复制到 `~/.local/share/fcitx5` |
| `kitty/` | kitty 终端模拟器配置 |
| `mako/` | 通知守护进程配置 |
| `matugen/` | 主题取色生成工具配置及模板 |
| `niri/` | niri 窗口管理器配置与脚本（含 `scripts/swayidle.sh`） |
| `satty/` | 截图标注工具配置 |
| `swaylock/` | 锁屏配置 |
| `waybar/` | 状态栏配置与脚本 |
| `waypaper/` | 壁纸工具配置 |
| `xdg-desktop-portal/` | niri 桌面门户配置 |

## 系统要求

- **Arch Linux** 系发行版（脚本依赖 `pacman`）
- 需要 `sudo`
- AUR 安装（`yay`）需普通用户执行，`niri_init.sh` 会自动检测并配置 **archlinuxcn** 源

## 使用方式

### 1. 部署 niri 桌面环境

```bash
./niri_init.sh
```

推荐选择菜单中的 **7）全部执行**，脚本会自动完成：

1. 检查系统环境
2. 安装 pacman 软件包（niri、输入法、文件管理器、waybar 等）
3. 安装 yay 与 AUR 软件包（剪贴板、壁纸工具）
4. 复制配置文件到 `~/.config`（覆盖前会备份 `niri` 目录）
5. 复制 fcitx5 配置到 `~/.local/share/fcitx5`
6. 启用 `ly` 登录管理器开机自启（`ly@tty1`）
7. 配置 Thunar 右键打开终端
8. 创建 Snapper 快照（root 与 home，可选）

也可通过菜单 `1-8` 单独执行其中任意步骤。

### 2. 安装常用软件

```bash
./install_software.sh
```

按菜单选择即可：

| 选项 | 内容 |
| --- | --- |
| 1 | 安装并配置 zsh（含 starship 与 kitty 配置） |
| 2 | 安装 KVM 并复制 `kvm_intel.conf`（启用嵌套虚拟化） |
| 3 | 安装常用软件（QQ、微信、WPS、VSCode、Edge、Lutris、HMCL、FlClash，可多选） |
| 4 | 显示脚本目录与可用配置文件 |

## 注意事项

- 脚本中的软件包来源于 pacman 官方仓库与 archlinuxcn 源，请确保网络可用。
- `niri_init.sh` 若以 root 运行，AUR 安装会通过 `SUDO_USER` 降权执行；请勿直接以 root 运行 `yay`。
- KVM 安装完成后需要**重新登录**以生效用户组变更。
- 配置文件采用**覆盖式复制**，部署前请注意备份个人自定义配置。
