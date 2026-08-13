## Preview

![preview](preview.png)

## 安装

```bash
sudo ./install.sh
```

## 手动安装

```bash
sudo cp -r blackice /boot/grub/themes/
# /etc/default/grub 中设置:
#   GRUB_THEME="/boot/grub/themes/blackice/theme.txt"
#   GRUB_GFXMODE="1920x1080,auto"
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## 致谢

- Arch 娘立绘:[ravimo — pixiv 101776734](https://www.pixiv.net/artworks/101776734)
- 字体:[JetBrains Mono](https://www.jetbrains.com/lp/mono/)(SIL Open Font License 1.1)
