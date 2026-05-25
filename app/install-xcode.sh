#!/bin/bash
# MyPace · Xcode 一键安装
# =========================
# 装 Xcode 16.4（macOS 15 Sequoia 兼容的最新稳定版）
# 用 xcodes + aria2 多线程加速下载

set -e

export PATH="/opt/homebrew/bin:$PATH"

XCODE_VERSION="16.4"
NOTICE_FILE="$HOME/MyPace-Swift/.xcode-install-status"

cat <<'EOF'
══════════════════════════════════════════════════════════
  MyPace · Xcode 自动安装
══════════════════════════════════════════════════════════

  即将安装 Xcode 16.4（最新且兼容 macOS 15.6 Sequoia）
  大小约 8 GB · 多线程下载约 20-40 min

  下面会问你 3 件事：
    1. Apple ID 邮箱（输入后回车）
    2. Apple ID 密码（输入时不显示，回车）
    3. 6 位 2FA 验证码（手机会弹通知，输入后回车）

  之后就全自动了。中途可以走开。

══════════════════════════════════════════════════════════
EOF
echo ""
read -p "准备好了按回车开始（Ctrl+C 取消）..."
echo ""

# 写状态文件，让 AI 监控
echo "started=$(date +%s)" > "$NOTICE_FILE"
echo "stage=downloading" >> "$NOTICE_FILE"

# 启动 xcodes install
# --experimental-unxip 用更快的解压器
# --empty-trash 装完后清理 .xip 节省空间
xcodes install "$XCODE_VERSION" \
  --experimental-unxip \
  --empty-trash \
  --update

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # 验证装好了
    if [ -d "/Applications/Xcode.app" ]; then
        echo ""
        echo "══════════════════════════════════════════════════════════"
        echo "  ✅ Xcode $XCODE_VERSION 安装完成！"
        echo "══════════════════════════════════════════════════════════"
        echo "  位置: /Applications/Xcode.app"

        # 自动接受协议 + 切换 xcode-select
        echo ""
        echo "▶ 切换 xcode-select 到新 Xcode（需要 sudo 密码）..."
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
        echo "▶ 接受 Xcode 许可协议..."
        sudo xcodebuild -license accept

        echo ""
        echo "  ✓ xcode-select 已指向 Xcode 16.4"
        echo "  ✓ 许可协议已接受"

        # 标记完成
        echo "stage=done" >> "$NOTICE_FILE"
        echo "done_at=$(date +%s)" >> "$NOTICE_FILE"

        echo ""
        echo "══════════════════════════════════════════════════════════"
        echo "  下一步：告诉 AI「装好了」，它会立刻 build MyPace 工程"
        echo "══════════════════════════════════════════════════════════"
    else
        echo "❌ xcodes 报告成功但找不到 /Applications/Xcode.app"
        echo "stage=missing" >> "$NOTICE_FILE"
        exit 1
    fi
else
    echo ""
    echo "❌ xcodes install 失败 (exit $EXIT_CODE)"
    echo "stage=failed" >> "$NOTICE_FILE"
    exit $EXIT_CODE
fi
