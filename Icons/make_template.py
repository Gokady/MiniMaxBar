#!/usr/bin/env python3
"""
把 .ico 转成 macOS template mode 的状态栏 PNG:
- 保留原 alpha 通道
- RGB 全置黑
- 配 isTemplate = true 后,macOS 自动根据菜单栏深浅反转成白色
"""
from PIL import Image
import os
import sys

SRC = "/Users/wuke/PycharmProjects/minimaxtools02/Icons/master/icon_1024.png"
DST = "/Users/wuke/PycharmProjects/minimaxtools02/Icons/statusbar"
SIZES = [(22, "icon_22.png"), (44, "icon_22@2x.png"), (66, "icon_22@3x.png")]

def to_template(src_path: str, dst_path: str, size: int):
    img = Image.open(src_path).convert("RGBA")
    # 上采样到目标尺寸(高质插值)
    img = img.resize((size, size), Image.LANCZOS)

    # 提取 alpha 通道,作为模板的 mask
    alpha = img.split()[3]

    # 模板:RGB 全黑 + 原 alpha
    template = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    template.putalpha(alpha)
    template.save(dst_path, "PNG")
    print(f"✓ {os.path.basename(dst_path)} ({size}x{size}, template)")

def main():
    for size, name in SIZES:
        to_template(SRC, os.path.join(DST, name), size)

if __name__ == "__main__":
    main()
