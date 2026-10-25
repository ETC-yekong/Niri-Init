#!/usr/bin/env bash
#
# niri_init.sh — niri 安装脚本 v2.0
#
# 依据 niri_init 参考文件编写, 包含:
#   1) 安装 niri 所需 pacman 软件包
#   2) 检查 yay 与 archlinuxcn 源, 安装 yay 后再安装 AUR 软件包
#   3) 将配置文件夹复制到 ~/.config
#   4) 复制 fcitx5 配置到 ~/.local/share
#   5) 启用 ly 开机自启, 并配置默认终端与 Thunar 右键打开终端
#
# 脚本界面语言跟随系统 locale: 中文环境输出中文, 其他环境输出英文,
# 避免在 tty 控制台 (通常没有中文字体) 下显示中文乱码。
# 如需强制指定语言, 可在运行时设置 SCRIPT_LANG=zh 或 SCRIPT_LANG=en。
#
# 用法: ./niri_init.sh

set -uo pipefail

# ================= 语言 / Language =================
# 跟随系统 locale 的优先级: LC_ALL > LC_MESSAGES > LANG
detect_lang() {
  local loc="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  loc="${loc,,}"
  case "$loc" in
    zh|zh_*|*_cn*|*_tw*|*_hk*|*_sg*) printf 'zh' ;;
    *) printf 'en' ;;
  esac
}
SCRIPT_LANG="${SCRIPT_LANG:-$(detect_lang)}"
# 兼容 SCRIPT_LANG=zh_CN 之类的写法
case "$SCRIPT_LANG" in
  zh*) SCRIPT_LANG="zh" ;;
  *)   SCRIPT_LANG="en" ;;
esac

# t "<中文>" "<English>" — 按当前语言返回对应文本
t() {
  if [[ "$SCRIPT_LANG" == "zh" ]]; then
    printf '%s' "${1:-}"
  else
    printf '%s' "${2:-${1:-}}"
  fi
}

# ================= 颜色 =================
if [[ -t 1 ]]; then
  C_RESET="\e[0m"; C_RED="\e[31m"; C_GREEN="\e[32m"
  C_YELLOW="\e[33m"; C_CYAN="\e[36m"; C_BOLD="\e[1m"; C_GRAY="\e[90m"
else
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""; C_BOLD=""; C_GRAY=""
fi

# ================= 路径 =================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 兼容通过 sudo 运行的情况, 取得真实用户的 HOME
if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  USER_HOME="$HOME"
fi

# ================= 日志 =================
log()   { printf "${C_GREEN}[%s]${C_RESET} %s\n" "$(t 信息 INFO)" "$(t "$@")"; }
warn()  { printf "${C_YELLOW}[%s]${C_RESET} %s\n" "$(t 警告 WARN)" "$(t "$@")"; }
error() { printf "${C_RED}[%s]${C_RESET} %s\n" "$(t 错误 ERROR)" "$(t "$@")" >&2; }
step()  { printf "\n${C_BOLD}${C_CYAN}===== %s =====${C_RESET}\n" "$(t "$@")"; }

# ================= 进度条 =================
# $1 已完成数量  $2 总数量  $3 标签
progress_bar() {
  local done="$1" total="$2" label="$3" percent filled width=38 i bar=""
  (( total <= 0 )) && total=1
  (( percent = done * 100 / total ))
  (( filled = percent * width / 100 ))
  for (( i = 0; i < width; i++ )); do
    (( i < filled )) && bar+="█" || bar+="─"
  done
  printf "\r  ${C_CYAN}%s${C_RESET} %3d%%  %s" "$bar" "$percent" "$label"
}

# ================= 软件包安装命令 =================
# 软件包分组名称使用 "中文|English" 形式存放, 由 action_label 按语言拼接。
# 命令中省略了 sudo, 由 run_pacman 根据运行身份自动处理。

PACMAN_CMDS=(
  "pacman -S --needed niri xdg-desktop-portal-gtk xdg-desktop-portal-gnome xwayland-satellite udiskie fuzzel kitty"
  "pacman -S --needed libnotify swaync polkit-gnome"
  "pacman -S --needed fcitx5-im fcitx5-rime rime-ice-pinyin-git rime-wanxiang-pinyin"
  "pacman -S --needed xdg-desktop-portal-gtk thunar tumbler ffmpegthumbnailer poppler-glib gvfs-smb file-roller thunar-archive-plugin gnome-keyring thunar-volman gvfs-mtp gvfs-gphoto2 webp-pixbuf-loader icoextract python-pillow xdg-terminal-exec"
  "pacman -S --needed swayidle"
  "pacman -S --needed mark-shot"
  "pacman -S --needed waybar ttf-jetbrains-mono-nerd otf-font-awesome bluetui gnome-clocks gnome-calendar brightnessctl matugen"
  "pacman -S --needed breeze-cursors"
  "pacman -S --needed ly"
)
PACMAN_GROUP_NAMES=(
  "基础组件|Base components" "通知功能|Notifications" "中文输入法|Chinese input method"
  "文件管理器|File manager" "自动熄屏|Idle management"
  "截图编辑|Screenshot annotation" "waybar 及组件|waybar and widgets"
  "鼠标指针|Cursor theme" "登录管理器 ly|ly login manager"
)

YAY_CMDS=(
  "yay -S --needed wl-clipboard clipse clipse-gui"
  "yay -S --needed swaylock-effects"
  "yay -S awww waypaper"
)
YAY_GROUP_NAMES=(
  "剪贴板工具|Clipboard tools" "锁屏特效|Lock screen effects" "壁纸工具|Wallpaper tools"
)

# action_label <中文动作> <English action> <"中文|English">
# 例如 action_label "安装" "Installing" "剪贴板工具|Clipboard tools"
action_label() {
  local zh="${3%%|*}" en="${3#*|}"
  if [[ "$SCRIPT_LANG" == "zh" ]]; then
    printf '%s%s' "$1" "$zh"
  else
    printf '%s %s' "$2" "$en"
  fi
}

# ================= 命令执行封装 =================
run_pacman() {
  if [[ $EUID -eq 0 ]]; then
    pacman "$@"
  else
    sudo pacman "$@"
  fi
}

# yay 严禁以 root 运行, 这里做安全处理
run_yay() {
  if [[ $EUID -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
      sudo -u "$SUDO_USER" env HOME="$USER_HOME" yay "$@"
    else
      error "yay 不能以 root 运行。请以普通用户执行本脚本, 或用 sudo 运行时保留 SUDO_USER 环境变量。" \
            "yay must not be run as root. Run this script as a normal user, or keep SUDO_USER when using sudo."
      return 1
    fi
  else
    yay "$@"
  fi
}

# ================= archlinuxcn 源与 yay =================
ensure_archlinuxcn_repo() {
  local pacman_conf="/etc/pacman.conf"
  if grep -qE '^[[:space:]]*\[archlinuxcn\]' "$pacman_conf" 2>/dev/null; then
    log "archlinuxcn 源已存在, 跳过添加。" "archlinuxcn repository already configured, skipping."
  else
    warn "未检测到 archlinuxcn 源, 正在添加..." "archlinuxcn repository not found, adding it..."
    local mirror="${ARCHLINUXCN_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch}"
    local entry
    entry="\n[archlinuxcn]\nSigLevel = Optional TrustedOnly\nServer = ${mirror}\n"

    # 修改前先备份
    local backup_path
    backup_path="${pacman_conf}.backup.$(date +%Y%m%d%H%M%S)"
    if [[ -f "$pacman_conf" ]]; then
      if [[ $EUID -eq 0 ]]; then
        cp -a "$pacman_conf" "$backup_path"
      else
        sudo cp -a "$pacman_conf" "$backup_path"
      fi
      log "已备份 $pacman_conf 到 $backup_path" "Backed up $pacman_conf to $backup_path"
    fi

    if [[ $EUID -eq 0 ]]; then
      printf '%b' "$entry" >> "$pacman_conf"
    else
      printf '%b' "$entry" | sudo tee -a "$pacman_conf" >/dev/null
    fi

    log "已添加 archlinuxcn 源, 刷新软件包数据库..." "archlinuxcn repository added, refreshing package databases..."
    run_pacman -Sy
  fi

  # archlinuxcn 的软件包使用该源自己的密钥签名, 缺少 keyring 会导致安装失败
  if ! pacman -Q archlinuxcn-keyring >/dev/null 2>&1; then
    log "安装 archlinuxcn-keyring..." "Installing archlinuxcn-keyring..."
    run_pacman -Sy --needed archlinuxcn-keyring
  fi
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    log "检测到 yay 已安装。" "yay is already installed."
    return 0
  fi

  warn "未检测到 yay, 尝试通过 archlinuxcn 源安装..." "yay not found, trying to install it from the archlinuxcn repository..."
  ensure_archlinuxcn_repo
  log "安装 yay..." "Installing yay..."
  run_pacman -S --needed yay

  if command -v yay >/dev/null 2>&1; then
    log "yay 安装成功。" "yay installed successfully."
    return 0
  fi
  error "yay 安装失败, 请检查 archlinuxcn 源配置后重试。" \
        "Failed to install yay. Check the archlinuxcn repository configuration and try again."
  return 1
}

# ================= 安装步骤 =================
install_pacman_packages() {
  step "安装 pacman 软件包" "Installing pacman packages"
  # 部分软件包 (rime 输入法、mark-shot) 来自 archlinuxcn, 需先配置好该源
  ensure_archlinuxcn_repo
  local n=${#PACMAN_CMDS[@]} i fail=0 gzh gen
  for (( i = 0; i < n; i++ )); do
    gzh="${PACMAN_GROUP_NAMES[$i]%%|*}"
    gen="${PACMAN_GROUP_NAMES[$i]#*|}"
    progress_bar "$i" "$n" "$(action_label "安装" "Installing" "${PACMAN_GROUP_NAMES[$i]}")"
    printf "\n  ${C_CYAN}>>> ${PACMAN_CMDS[$i]}${C_RESET}\n"
    if ! run_pacman ${PACMAN_CMDS[$i]#pacman }; then
      error "${gzh}安装失败。" "Failed to install ${gen}."
      ((fail++))
    fi
  done
  progress_bar "$n" "$n" "$(t "pacman 软件包安装完成" "pacman packages installed")"
  printf "\n"
  if (( fail > 0 )); then
    warn "共有 $fail 组 pacman 软件包安装失败, 请根据上方错误信息处理。" \
         "$fail pacman package group(s) failed. See the error messages above."
  fi
}

install_yay_packages() {
  step "安装 yay 与 AUR 软件包" "Installing yay and AUR packages"
  if ! ensure_yay; then
    error "yay 不可用, 跳过 AUR 软件包安装。" "yay is unavailable, skipping AUR packages."
    return 1
  fi
  local n=${#YAY_CMDS[@]} i fail=0 gzh gen
  for (( i = 0; i < n; i++ )); do
    gzh="${YAY_GROUP_NAMES[$i]%%|*}"
    gen="${YAY_GROUP_NAMES[$i]#*|}"
    progress_bar "$i" "$n" "$(action_label "安装" "Installing" "${YAY_GROUP_NAMES[$i]}")"
    printf "\n  ${C_CYAN}>>> ${YAY_CMDS[$i]}${C_RESET}\n"
    if ! run_yay ${YAY_CMDS[$i]#yay }; then
      error "${gzh}安装失败。" "Failed to install ${gen}."
      ((fail++))
    fi
  done
  progress_bar "$n" "$n" "$(t "AUR 软件包安装完成" "AUR packages installed")"
  printf "\n"
  if (( fail > 0 )); then
    warn "共有 $fail 组 AUR 软件包安装失败, 请根据上方错误信息处理。" \
         "$fail AUR package group(s) failed. See the error messages above."
  fi
}

copy_configs() {
  step "复制配置文件到 ~/.config" "Copying configuration files to ~/.config"
  local dirs=(niri kitty swaync matugen mark-shot swaylock waybar waypaper xdg-desktop-portal)
  local n=${#dirs[@]} i dir src dst
  for (( i = 0; i < n; i++ )); do
    dir="${dirs[$i]}"
    src="$SCRIPT_DIR/$dir"
    dst="$USER_HOME/.config/$dir"
    progress_bar "$i" "$n" "$(t "正在复制 $dir" "Copying $dir")"
    if [[ ! -d "$src" ]]; then
      printf "\n"
      warn "未找到目录 $src, 跳过 $dir。" "Directory $src not found, skipping $dir."
      continue
    fi
    mkdir -p "$USER_HOME/.config"
    if [[ -d "$dst" ]]; then
      # 替换前为 niri 配置保留一份备份
      if [[ "$dir" == "niri" ]]; then
        cp -r "$dst" "${dst}.backup.$(date +%Y%m%d%H%M%S)"
      fi
      rm -rf "$dst"
    fi
    cp -r "$src" "$dst"
    printf "\n  ${C_GREEN}%s${C_RESET} $dir -> $dst\n" "$(t "完成:" "Done:")"
  done
  progress_bar "$n" "$n" "$(t "配置文件复制完成" "Configuration files copied")"
  printf "\n"
}

copy_fcitx5() {
  step "复制 fcitx5 配置到 ~/.local/share" "Copying fcitx5 configuration to ~/.local/share"
  local src="$SCRIPT_DIR/fcitx5"
  local dst="$USER_HOME/.local/share/fcitx5"
  if [[ ! -d "$src" ]]; then
    warn "未找到目录 $src, 跳过。" "Directory $src not found, skipping."
    return 1
  fi
  mkdir -p "$USER_HOME/.local/share"
  if [[ -d "$dst" ]]; then
    rm -rf "$dst"
  fi
  cp -r "$src" "$dst"
  log "fcitx5 配置已复制到 $dst" "fcitx5 configuration copied to $dst"
}

enable_ly() {
  step "启用 ly 开机自启" "Enabling ly at boot"
  if [[ $EUID -eq 0 ]]; then
    if ! systemctl enable ly@tty1; then
      error "启用 ly@tty1 服务失败, 请确认 ly 已安装。" "Failed to enable ly@tty1. Make sure ly is installed."
      return 1
    fi
  else
    if ! sudo systemctl enable ly@tty1; then
      error "启用 ly@tty1 服务失败, 请确认 ly 已安装。" "Failed to enable ly@tty1. Make sure ly is installed."
      return 1
    fi
  fi
  log "已启用 ly@tty1 服务。" "ly@tty1 service enabled."
}

setup_terminal_file() {
  step "配置默认终端与 Thunar 右键终端" "Configuring the default terminal and Thunar “Open Terminal”"
  local list_file="$USER_HOME/.config/xdg-terminals.list"
  mkdir -p "$(dirname "$list_file")"
  if grep -qF "kitty.desktop" "$list_file" 2>/dev/null; then
    log "xdg-terminals.list 已包含 kitty.desktop, 无需重复添加。" \
        "xdg-terminals.list already contains kitty.desktop, nothing to add."
  else
    printf '%s\n' "kitty.desktop" >> "$list_file"
    log "已将 kitty.desktop 写入 $list_file" "kitty.desktop written to $list_file"
  fi

  # Thunar 的“打开终端”通过 exo-open 读取 xfce4/helpers.rc 选择终端
  local helpers_file="$USER_HOME/.config/xfce4/helpers.rc"
  mkdir -p "$(dirname "$helpers_file")"
  if grep -qE '^[[:space:]]*TerminalEmulator=' "$helpers_file" 2>/dev/null; then
    if grep -qE '^[[:space:]]*TerminalEmulator=kitty[[:space:]]*$' "$helpers_file"; then
      log "helpers.rc 已指定 kitty, 无需修改。" "helpers.rc already selects kitty, nothing to change."
    else
      sed -i -E 's|^[[:space:]]*TerminalEmulator=.*$|TerminalEmulator=kitty|' "$helpers_file"
      log "已将 helpers.rc 的终端更新为 kitty。" "Updated the terminal in helpers.rc to kitty."
    fi
  else
    printf '%s\n' "TerminalEmulator=kitty" >> "$helpers_file"
    log "已将 TerminalEmulator=kitty 写入 $helpers_file" "Wrote TerminalEmulator=kitty to $helpers_file"
  fi
}

create_snapshot() {
  step "创建 Snapper 快照" "Creating Snapper snapshots"
  if ! command -v snapper >/dev/null 2>&1; then
    warn "未检测到 snapper, 跳过快照创建。请先安装并配置 snapper。" \
         "snapper not found, skipping snapshots. Install and configure snapper first."
    return 1
  fi
  local rc=0
  if [[ $EUID -eq 0 ]]; then
    snapper -c root create --description "niri-init" || rc=1
    snapper -c home create --description "niri-init" || rc=1
  else
    sudo snapper -c root create --description "niri-init" || rc=1
    sudo snapper -c home create --description "niri-init" || rc=1
  fi
  if (( rc != 0 )); then
    error "快照创建失败, 请确认 snapper 的 root/home 配置已存在 (snapper -c <config> list)。" \
          "Failed to create snapshots. Make sure the snapper root/home configs exist (snapper -c <config> list)."
    return 1
  fi
  log "已创建 root 与 home 的 niri-init 快照。" "Created niri-init snapshots for root and home."
}

prepare_env() {
  step "检查系统环境" "Checking the system environment"
  if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
    warn "当前以 root 运行。AUR 软件包 (yay) 需要普通用户执行, 建议以普通用户身份运行本脚本。" \
         "Running as root. AUR packages (yay) must be built by a normal user; run this script as a normal user instead."
  fi
  if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    error "未检测到 sudo, 无法安装软件包。" "sudo not found, cannot install packages."
    return 1
  fi
  if ! command -v pacman >/dev/null 2>&1; then
    error "未检测到 pacman, 本脚本仅支持 Arch Linux 系发行版。" \
          "pacman not found. This script only supports Arch Linux based distributions."
    return 1
  fi
  log "系统环境检查完成。" "System environment check completed."
}

# ================= 全部执行 =================
run_full() {
  # 格式: 函数名|中文名称|English name
  local steps=(
    "prepare_env|检查系统环境|Checking the system environment"
    "install_pacman_packages|安装 pacman 软件包|Installing pacman packages"
    "install_yay_packages|安装 yay 与 AUR 软件包|Installing yay and AUR packages"
    "copy_configs|复制配置文件|Copying configuration files"
    "copy_fcitx5|复制 fcitx5 配置|Copying fcitx5 configuration"
    "enable_ly|启用 ly 开机自启|Enabling ly at boot"
    "setup_terminal_file|配置默认终端与 Thunar 右键终端|Configuring the default terminal and Thunar “Open Terminal”"
    "create_snapshot|创建 Snapper 快照|Creating Snapper snapshots"
  )
  local total=${#steps[@]} i entry name_zh name_en func rc
  for (( i = 0; i < total; i++ )); do
    entry="${steps[$i]}"
    func="${entry%%|*}"
    entry="${entry#*|}"
    name_zh="${entry%%|*}"
    name_en="${entry#*|}"
    printf "\n"
    progress_bar "$i" "$total" "$(t "整体进度 — 即将开始: $name_zh" "Overall progress — starting: $name_en")"
    printf "\n"
    "$func"
    rc=$?
    if [[ "$func" == "prepare_env" && "$rc" -ne 0 ]]; then
      error "环境检查未通过, 中止全部执行。" "Environment check failed, aborting."
      return 1
    fi
  done
  printf "\n"
  progress_bar "$total" "$total" "$(t "全部完成" "All done")"
  printf "\n"
  log "所有步骤执行完毕。" "All steps completed."
}

# ================= 交互菜单 =================
show_menu() {
  printf "\n"
  printf "  ${C_BOLD}${C_CYAN}================== $(t "niri 安装脚本 v2.0" "niri installer v2.0") ==================${C_RESET}\n"
  printf "\n"
  printf "  ${C_BOLD}%s${C_RESET}\n" "$(t "请选择要执行的操作:" "Select an action:")"
  printf "\n"
  printf "    ${C_GREEN}1${C_RESET}) %s\n" "$(t "安装 pacman 软件包" "Install pacman packages")"
  printf "    ${C_GREEN}2${C_RESET}) %s\n" "$(t "安装 yay 与 AUR 软件包" "Install yay and AUR packages")"
  printf "    ${C_GREEN}3${C_RESET}) %s\n" "$(t "复制配置文件到 ~/.config" "Copy configuration files to ~/.config")"
  printf "    ${C_GREEN}4${C_RESET}) %s\n" "$(t "复制 fcitx5 配置" "Copy fcitx5 configuration")"
  printf "    ${C_GREEN}5${C_RESET}) %s\n" "$(t "启用 ly 开机自启" "Enable ly at boot")"
  printf "    ${C_GREEN}6${C_RESET}) %s\n" "$(t "配置默认终端与 Thunar 右键打开终端" "Configure the default terminal and Thunar “Open Terminal”")"
  printf "    ${C_GREEN}7${C_RESET}) ${C_BOLD}%s${C_RESET} %s\n" \
    "$(t "全部执行" "Run everything")" "$(t "(推荐)" "(recommended)")"
  printf "    ${C_GREEN}8${C_RESET}) %s\n" "$(t "创建 Snapper 快照 (root 与 home)" "Create Snapper snapshots (root and home)")"
  printf "    ${C_GREEN}0${C_RESET}) %s\n" "$(t "退出" "Quit")"
  printf "\n"
  printf "  %s " "$(t "请输入选项编号:" "Enter option number:")"
}

main() {
  local choice
  while true; do
    show_menu
    if ! read -r choice; then
      # 输入结束 (如管道/EOF) 时正常退出, 避免空输入导致死循环
      printf "\n"
      log "输入已结束, 退出。" "Input closed, exiting."
      exit 0
    fi
    case "$choice" in
      1) install_pacman_packages ;;
      2) install_yay_packages ;;
      3) copy_configs ;;
      4) copy_fcitx5 ;;
      5) enable_ly ;;
      6) setup_terminal_file ;;
      7) run_full ;;
      8) create_snapshot ;;
      0|q|Q) log "已退出。" "Exited."; exit 0 ;;
      *) warn "无效选项: ${choice:-空}, 请输入 0-8。" \
              "Invalid option: ${choice:-<empty>}, enter 0-8." ;;
    esac
    printf "\n"
    read -rp "$(t "按回车返回主菜单..." "Press Enter to return to the menu...")" _
  done
}

main "$@"
