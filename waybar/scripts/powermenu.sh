#!/bin/bash
# waybar 电源菜单：挂起 / 休眠 / 关机 / 重启

# 以 Nerd Font 图标 + 中文文本作为菜单项
options="󰒲   挂起\n󰥈   休眠\n󰐥   关机\n󰜎   重启"

# 通过 fuzzel 的 dmenu 模式弹出选择（无选择直接退出）
choice=$(printf "$options" | fuzzel --dmenu --prompt "电源菜单" --width 40 --lines 4)

case "$choice" in
    *挂起*) systemctl suspend ;;
    *休眠*) systemctl hibernate ;;
    *关机*) poweroff ;;
    *重启*) reboot ;;
esac