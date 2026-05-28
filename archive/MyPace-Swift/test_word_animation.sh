#!/bin/bash
# 端到端测试字级动效：预先 seed 一个带 word timestamps 的脚本，
# 让 app 启动后立刻进入播放状态，捕捉多帧截图看缩放效果

set -e

cd ~/MyPace-Swift

# 1. 杀掉旧 app
pkill -f MyPacePreview 2>/dev/null || true
sleep 1

# 2. 清掉所有用户数据 + 让 visible 模式打开
rm -rf ~/Library/Application\ Support/MyPacePreview
defaults write ai.mypace.preview hasSeenWelcome -bool true
defaults write ai.mypace.preview allowScreenCapture -bool true
defaults write ai.mypace.preview currentFontSize -float 36

# 3. 用一个 helper 直接 seed 带 rhythm 的脚本（用之前测试拿到的真实 word timestamps）
mkdir -p ~/Library/Application\ Support/MyPacePreview/scripts

# 这是一份带真实 word timestamps 的稿件 JSON（用前面 verify_word_playback 拿到的数据）
cat > ~/Library/Application\ Support/MyPacePreview/scripts/00000000-0000-0000-0000-000000000001.json <<'JSON'
{
  "createdAt": "2026-05-24T13:00:00Z",
  "id": "00000000-0000-0000-0000-000000000001",
  "lines": [
    "很多人以为定价是个数学题，其实它更像一场心理游戏。",
    "你卖的不是产品本身，而是它在客户心里值多少。"
  ],
  "rhythm": {
    "audioFilename": "test.wav",
    "createdAt": "2026-05-24T13:00:00Z",
    "segments": [
      {
        "confidence": 0.95,
        "endTime": 5.44,
        "index": 0,
        "startTime": 0.12,
        "text": "很多人以为定价是个数学题，其实它更像一场心理游戏。",
        "words": [
          {"endTime":0.28,"startTime":0.12,"text":"很"},
          {"endTime":0.44,"startTime":0.28,"text":"多"},
          {"endTime":0.64,"startTime":0.44,"text":"人"},
          {"endTime":0.84,"startTime":0.64,"text":"以"},
          {"endTime":1.00,"startTime":0.84,"text":"为"},
          {"endTime":1.24,"startTime":1.04,"text":"定"},
          {"endTime":1.48,"startTime":1.24,"text":"价"},
          {"endTime":1.72,"startTime":1.48,"text":"是"},
          {"endTime":1.96,"startTime":1.72,"text":"个"},
          {"endTime":2.20,"startTime":2.00,"text":"数"},
          {"endTime":2.44,"startTime":2.20,"text":"学"},
          {"endTime":2.72,"startTime":2.44,"text":"题"},
          {"endTime":3.24,"startTime":3.04,"text":"其"},
          {"endTime":3.40,"startTime":3.24,"text":"实"},
          {"endTime":3.60,"startTime":3.48,"text":"它"},
          {"endTime":3.92,"startTime":3.68,"text":"更"},
          {"endTime":4.16,"startTime":3.92,"text":"像"},
          {"endTime":4.40,"startTime":4.16,"text":"一"},
          {"endTime":4.64,"startTime":4.40,"text":"场"},
          {"endTime":4.88,"startTime":4.64,"text":"心"},
          {"endTime":5.12,"startTime":4.88,"text":"理"},
          {"endTime":5.40,"startTime":5.12,"text":"游"},
          {"endTime":5.44,"startTime":5.40,"text":"戏"}
        ]
      },
      {
        "confidence": 0.95,
        "endTime": 9.60,
        "index": 1,
        "startTime": 5.80,
        "text": "你卖的不是产品本身，而是它在客户心里值多少。",
        "words": [
          {"endTime":6.00,"startTime":5.80,"text":"你"},
          {"endTime":6.24,"startTime":6.00,"text":"卖"},
          {"endTime":6.48,"startTime":6.24,"text":"的"},
          {"endTime":6.72,"startTime":6.48,"text":"不"},
          {"endTime":6.96,"startTime":6.72,"text":"是"},
          {"endTime":7.20,"startTime":6.96,"text":"产"},
          {"endTime":7.44,"startTime":7.20,"text":"品"},
          {"endTime":7.68,"startTime":7.44,"text":"本"},
          {"endTime":7.92,"startTime":7.68,"text":"身"},
          {"endTime":8.20,"startTime":8.00,"text":"而"},
          {"endTime":8.44,"startTime":8.20,"text":"是"},
          {"endTime":8.68,"startTime":8.44,"text":"它"},
          {"endTime":8.96,"startTime":8.68,"text":"在"},
          {"endTime":9.20,"startTime":8.96,"text":"客"},
          {"endTime":9.40,"startTime":9.20,"text":"户"},
          {"endTime":9.52,"startTime":9.40,"text":"心"},
          {"endTime":9.56,"startTime":9.52,"text":"里"},
          {"endTime":9.60,"startTime":9.56,"text":"值"}
        ]
      }
    ],
    "totalDuration": 10.0
  },
  "title": "字级动效测试",
  "updatedAt": "2026-05-24T13:00:00Z"
}
JSON

echo "✓ 预置带 word timestamps 的稿件"

# 4. 启动 app
open "/Applications/MyPace Preview.app"
sleep 3

# 5. 让 MyPace 成为前台
osascript -e 'tell application "System Events" to set frontmost of every process whose name contains "MyPacePreview" to true' 2>&1 | head -1
sleep 1

# 6. 用 osascript 模拟按 Space 触发播放
echo "▶ 模拟按 Space 触发播放..."
osascript -e 'tell application "System Events" to key code 49' 2>&1 | head -1
sleep 0.5

# 7. 连续截 5 张图，每隔 0.6 秒，看缩放变化
echo "▶ 连续截图..."
for i in 1 2 3 4 5 6; do
  screencapture -x -t png "/tmp/anim_$i.png"
  echo "  shot $i"
  sleep 0.6
done

echo ""
echo "✅ 6 帧截图已存在 /tmp/anim_1.png … /tmp/anim_6.png"
