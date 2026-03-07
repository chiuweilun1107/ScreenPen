# ScreenPen

macOS 螢幕畫筆工具 — 在螢幕上直接繪圖、標註、教學演示。

類似 [Presentify](https://presentifyapp.com/)，完全免費開源。

## 安裝

1. 從 [Releases](https://github.com/chiuweilun1107/ScreenPen/releases) 下載 `ScreenPen.dmg`
2. 打開 DMG，拖曳 ScreenPen 到 Applications
3. 首次啟動：右鍵點擊 ScreenPen.app → 打開（繞過 Gatekeeper）
4. 授權「輔助使用」權限（系統設定 > 隱私權與安全性 > 輔助使用）

**系統需求：** macOS 13.0+

## 功能

### 繪圖工具
| 快捷鍵 | 工具 |
|--------|------|
| F | 畫筆（Freehand） |
| A | 箭頭 |
| L | 直線 |
| R | 矩形 |
| C | 圓形 |
| H | 螢光筆 |
| T | 文字標註 |
| E | 橡皮擦 |

### 模式
| 快捷鍵 | 功能 |
|--------|------|
| Space | Fade 淡出模式（標註自動消失） |
| W | 白板 / 黑板模式 |
| K | 游標聚光燈 |
| I | Interactive 模式（Fn 切換繪圖/操作） |
| Shift | 約束（直線 0°/45°/90°，矩形/圓形→正方形/正圓） |

### 操作
| 快捷鍵 | 功能 |
|--------|------|
| ⌃A | 全域開啟/暫離繪圖 |
| S | 螢幕截圖（存桌面 + 剪貼簿） |
| 1-5 | 顏色（紅/橙/黃/綠/藍） |
| [ / ] | 線寬調整 |
| ⌘Z / ⌘⇧Z | 復原 / 重做 |
| ⌫ | 刪除最後一筆 |
| ⌥⌫ | 清除全部 + 關閉 |
| Escape | 暫離（畫面保留） |
| ⌘, | 設定面板 |

### 自訂快捷鍵

所有工具和功能的快捷鍵都可以在 **Settings > Shortcuts** 分頁中重新綁定。

## 技術棧

- Swift 5 + AppKit
- NSPanel（nonactivatingPanel）透明 overlay
- NSBezierPath 向量繪圖
- Carbon RegisterEventHotKey 全域快捷鍵（繞過輸入法）
- UserDefaults 設定持久化

## 從原始碼建置

```bash
git clone https://github.com/chiuweilun1107/ScreenPen.git
cd ScreenPen
xcodebuild -project ScreenPen.xcodeproj -scheme ScreenPen -configuration Release build

# 建置 DMG
bash scripts/build-dmg.sh
```

## 開發紀錄

### v0.4.1 — Custom Shortcuts
- 自訂快捷鍵 UI（Settings > Shortcuts 分頁）
- 20 個動作可重新綁定，衝突自動交換
- 單獨重置 / 一鍵全部重置

### v0.4.0 — Phase 3
- 文字標註（T key）
- 螢幕截圖（S key）
- Interactive 模式（I + Fn）
- 設定面板（⌘,）
- DMG 打包腳本

### v0.3.0 — Phase 2
- Shift 約束（直線/正方形/正圓）
- Fade 淡出模式
- 浮動 HUD 狀態顯示
- 白板/黑板模式
- 游標聚光燈

### v0.2.0 — Stable Core
- 8 種繪圖工具
- 全域快捷鍵 ⌃A（Carbon HotKey）
- keyCode 工具快捷鍵（繞過 IME）
- 多螢幕支援
- Undo/Redo
- 暫離模式（Escape）

## License

MIT
