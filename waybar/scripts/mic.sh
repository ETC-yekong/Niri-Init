#!/bin/bash
# 显示默认麦克风状态：󰍬 音量% / 󰍭 静音
muted=$(wpctl get-mute @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
vol=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{print $2}')
if [ -z "$vol" ]; then
    vol=0
fi
pct=$(awk -v v="$vol" 'BEGIN{printf "%d", v*100}')
if echo "$muted" | grep -q "yes"; then
    echo "󰍭"
else
    echo "󰍬${pct}%"
fi
