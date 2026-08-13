#!/bin/bash
# waybar 媒体播放/暂停图标（实时跟随播放状态）
# 播放中显示暂停图标，暂停/未播放显示播放图标

status=$(playerctl status 2>/dev/null)

if [[ "$status" == "Playing" ]]; then
    echo "󰏤"
else
    echo "󰐊"
fi
