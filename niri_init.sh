#!/usr/bin/env bash
#
# niri_init.sh — niri 安装脚本 v2.0
#
# 依据 niri_init 参考文件编写, 包含:
#   1) 安装 niri 所需 pacman 软件包
#   2) 检查 yay 与 archlinuxcn 源, 安装 yay 后再安装 AUR 软件包
#   3) 将配置文件夹复制到 ~/.config
#   4) 复制 fcitx5 配置到 ~/.local/share
#   5) 启用 ly 开机自启, 并配置 Thunar 右键打开终端
#
# 用法: ./niri_init.sh

set -uo pipefail

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
log()   { printf "${C_GREEN}[信息]${C_RESET} %s\n" "$1"; }
warn()  { printf "${C_YELLOW}[警告]${C_RESET} %s\n" "$1"; }
error() { printf "${C_RED}[错误]${C_RESET} %s\n" "$1" >&2; }
step()  { printf "\n${C_BOLD}${C_CYAN}===== %s =====${C_RESET}\n" "$1"; }

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
# 注意: 以下包名与参数均照抄自 niri_init, 请勿改动。
# 命令中省略了 sudo, 由 run_pacman 根据运行身份自动处理。

PACMAN_CMDS=(
  "pacman -S --needed niri xdg-desktop-portal-gtk xdg-desktop-portal-gnome xwayland-satellite udiskie fuzzel kitty"
  "pacman -S --needed libnotify mako polkit-gnome"
  "pacman -S --needed fcitx5-im fcitx5-rime rime-ice-pinyin rime-wanxiang-pinyin"
  "pacman -S --needed xdg-desktop-portal-gtk thunar tumbler ffmpegthumbnailer poppler-glib gvfs-smb file-roller thunar-archive-plugin gnome-keyring thunar-volman gvfs-mtp gvfs-gphoto2 webp-pixbuf-loader icoextract python-pillow xdg-terminal-exec"
  "pacman -S --needed swaylock-effects"
  "pacman -S swayidle"
  "pacman -S satty"
  "pacman -S --needed waybar ttf-jetbrains-mono-nerd otf-font-awesome bluetui gnome-clocks gnome-calendar brightnessctl matugen"
  "pacman -S breeze-cursors"
  "pacman -S ly"
)
PACMAN_GROUP_NAMES=(
  "基础组件" "通知功能" "中文输入法" "文件管理器" "锁屏"
  "自动熄屏" "截图编辑" "waybar 及组件" "鼠标指针" "登录管理器 ly"
)

YAY_CMDS=(
  "yay -S --needed wl-clipboard clipse clipse-gui"
  "yay -S awww waypaper"
)
YAY_GROUP_NAMES=("剪贴板工具" "壁纸工具")

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
      error "yay 不能以 root 运行。请以普通用户执行本脚本, 或用 sudo 运行时保留 SUDO_USER 环境变量。"
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
    log "archlinuxcn 源已存在, 跳过添加。"
    return 0
  fi

  warn "未检测到 archlinuxcn 源, 正在添加..."
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
    log "已备份 $pacman_conf 到 $backup_path"
  fi

  if [[ $EUID -eq 0 ]]; then
    printf '%b' "$entry" >> "$pacman_conf"
  else
    printf '%b' "$entry" | sudo tee -a "$pacman_conf" >/dev/null
  fi

  log "已添加 archlinuxcn 源, 刷新软件包数据库..."
  run_pacman -Sy
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    log "检测到 yay 已安装。"
    return 0
  fi

  warn "未检测到 yay, 尝试通过 archlinuxcn 源安装..."
  ensure_archlinuxcn_repo
  log "更新 archlinuxcn-keyring..."
  run_pacman -Sy archlinuxcn-keyring
  log "安装 yay..."
  run_pacman -S --needed yay

  if command -v yay >/dev/null 2>&1; then
    log "yay 安装成功。"
    return 0
  fi
  error "yay 安装失败, 请检查 archlinuxcn 源配置后重试。"
  return 1
}

# ================= 安装步骤 =================
install_pacman_packages() {
  step "安装 pacman 软件包"
  local n=${#PACMAN_CMDS[@]} i fail=0
  for (( i = 0; i < n; i++ )); do
    progress_bar "$i" "$n" "安装 ${PACMAN_GROUP_NAMES[$i]}"
    printf "\n  ${C_CYAN}>>> ${PACMAN_CMDS[$i]}${C_RESET}\n"
    if ! run_pacman ${PACMAN_CMDS[$i]#pacman }; then
      error "安装 ${PACMAN_GROUP_NAMES[$i]} 失败。"
      ((fail++))
    fi
  done
  progress_bar "$n" "$n" "pacman 软件包安装完成"
  printf "\n"
  if (( fail > 0 )); then
    warn "共有 $fail 组 pacman 软件包安装失败, 请根据上方错误信息处理。"
  fi
}

install_yay_packages() {
  step "安装 yay 与 AUR 软件包"
  if ! ensure_yay; then
    error "yay 不可用, 跳过 AUR 软件包安装。"
    return 1
  fi
  local n=${#YAY_CMDS[@]} i fail=0
  for (( i = 0; i < n; i++ )); do
    progress_bar "$i" "$n" "安装 ${YAY_GROUP_NAMES[$i]}"
    printf "\n  ${C_CYAN}>>> ${YAY_CMDS[$i]}${C_RESET}\n"
    if ! run_yay ${YAY_CMDS[$i]#yay }; then
      error "安装 ${YAY_GROUP_NAMES[$i]} 失败。"
      ((fail++))
    fi
  done
  progress_bar "$n" "$n" "AUR 软件包安装完成"
  printf "\n"
  if (( fail > 0 )); then
    warn "共有 $fail 组 AUR 软件包安装失败, 请根据上方错误信息处理。"
  fi
}

copy_configs() {
  step "复制配置文件到 ~/.config"
  local dirs=(niri kitty mako matugen satty swaylock waybar waypaper xdg-desktop-portal)
  local n=${#dirs[@]} i dir src dst
  for (( i = 0; i < n; i++ )); do
    dir="${dirs[$i]}"
    src="$SCRIPT_DIR/$dir"
    dst="$USER_HOME/.config/$dir"
    progress_bar "$i" "$n" "正在复制 $dir"
    if [[ ! -d "$src" ]]; then
      printf "\n"
      warn "未找到目录 $src, 跳过 $dir。"
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
    printf "\n  ${C_GREEN}完成:${C_RESET} $dir -> $dst\n"
  done
  progress_bar "$n" "$n" "配置文件复制完成"
  printf "\n"
}

copy_fcitx5() {
  step "复制 fcitx5 配置到 ~/.local/share"
  local src="$SCRIPT_DIR/fcitx5"
  local dst="$USER_HOME/.local/share/fcitx5"
  if [[ ! -d "$src" ]]; then
    warn "未找到目录 $src, 跳过。"
    return 1
  fi
  mkdir -p "$USER_HOME/.local/share"
  if [[ -d "$dst" ]]; then
    rm -rf "$dst"
  fi
  cp -r "$src" "$dst"
  log "fcitx5 配置已复制到 $dst"
}

enable_ly() {
  step "启用 ly 开机自启"
  if [[ $EUID -eq 0 ]]; then
    if ! systemctl enable ly@tty1; then
      error "启用 ly@tty1 服务失败, 请确认 ly 已安装。"
      return 1
    fi
  else
    if ! sudo systemctl enable ly@tty1; then
      error "启用 ly@tty1 服务失败, 请确认 ly 已安装。"
      return 1
    fi
  fi
  log "已启用 ly@tty1 服务。"
}

setup_terminal_file() {
  step "配置 Thunar 右键打开终端"
  local list_file="$USER_HOME/.config/xdg-terminal.list"
  mkdir -p "$(dirname "$list_file")"
  if grep -qF "kitty.desktop" "$list_file" 2>/dev/null; then
    log "xdg-terminal.list 已包含 kitty.desktop, 无需重复添加。"
  else
    printf '%s\n' "kitty.desktop" >> "$list_file"
    log "已将 kitty.desktop 写入 $list_file"
  fi
}

create_snapshot() {
  step "创建 Snapper 快照"
  if ! command -v snapper >/dev/null 2>&1; then
    warn "未检测到 snapper, 跳过快照创建。请先安装并配置 snapper。"
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
    error "快照创建失败, 请确认 snapper 的 root/home 配置已存在 (snapper -c <config> list)。"
    return 1
  fi
  log "已创建 root 与 home 的 niri-init 快照。"
}

prepare_env() {
  step "检查系统环境"
  if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
    warn "当前以 root 运行。AUR 软件包 (yay) 需要普通用户执行, 建议以普通用户身份运行本脚本。"
  fi
  if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    error "未检测到 sudo, 无法安装软件包。"
    return 1
  fi
  if ! command -v pacman >/dev/null 2>&1; then
    error "未检测到 pacman, 本脚本仅支持 Arch Linux 系发行版。"
    return 1
  fi
  log "系统环境检查完成。"
}

# ================= 全部执行 =================
run_full() {
  local steps=(
    "检查系统环境|prepare_env"
    "安装 pacman 软件包|install_pacman_packages"
    "安装 yay 与 AUR 软件包|install_yay_packages"
    "复制配置文件|copy_configs"
    "复制 fcitx5 配置|copy_fcitx5"
    "启用 ly 开机自启|enable_ly"
    "配置 Thunar 右键终端|setup_terminal_file"
    "创建 Snapper 快照|create_snapshot"
  )
  local total=${#steps[@]} i name func rc
  for (( i = 0; i < total; i++ )); do
    name="${steps[$i]%%|*}"
    func="${steps[$i]##*|}"
    printf "\n"
    progress_bar "$i" "$total" "整体进度 — 即将开始: $name"
    printf "\n"
    "$func"
    rc=$?
    if [[ "$func" == "prepare_env" && "$rc" -ne 0 ]]; then
      error "环境检查未通过, 中止全部执行。"
      return 1
    fi
  done
  printf "\n"
  progress_bar "$total" "$total" "全部完成"
  printf "\n"
  log "所有步骤执行完毕。"
}

# ================= 交互菜单 =================
show_menu() {
  printf "\n"
  printf "  ${C_BOLD}${C_CYAN}================== niri 安装脚本 v2.0 ==================${C_RESET}\n"
  printf "\n"
  printf "  ${C_BOLD}请选择要执行的操作:${C_RESET}\n"
  printf "\n"
  printf "    ${C_GREEN}1${C_RESET}) 安装 pacman 软件包\n"
  printf "    ${C_GREEN}2${C_RESET}) 安装 yay 与 AUR 软件包\n"
  printf "    ${C_GREEN}3${C_RESET}) 复制配置文件到 ~/.config\n"
  printf "    ${C_GREEN}4${C_RESET}) 复制 fcitx5 配置\n"
  printf "    ${C_GREEN}5${C_RESET}) 启用 ly 开机自启\n"
  printf "    ${C_GREEN}6${C_RESET}) 配置 Thunar 右键打开终端\n"
  printf "    ${C_GREEN}7${C_RESET}) ${C_BOLD}全部执行${C_RESET} (推荐)\n"
  printf "    ${C_GREEN}8${C_RESET}) 创建 Snapper 快照 (root 与 home)\n"
  printf "    ${C_GREEN}0${C_RESET}) 退出\n"
  printf "\n"
  printf "  请输入选项编号: "
}

main() {
  local choice
  while true; do
    show_menu
    if ! read -r choice; then
      choice=""
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
      0|q|Q) log "已退出。"; exit 0 ;;
      *) warn "无效选项: ${choice:-空}, 请输入 0-8。" ;;
    esac
    printf "\n"
    read -rp "按回车返回主菜单..." _
  done
}

main "$@"
