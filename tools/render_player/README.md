# プレイヤーの絵を3Dモデルから焼く

プレイヤーは3Dモデルを8方向×歩き4コマの絵（`assets/sprites/player_sheet.png`）に焼いて表示しています。
ゲームの中では3Dを使わず、この絵を `scenes/player/player.gd` が向きと歩きに合わせて切り出して描きます。

## 焼き直す手順

1. Godot 4.5 でこのプロジェクトを開く。
2. `tools/render_player/render_player.tscn` を開き、「現在のシーンを実行」（F6）を押す。
3. 数秒で窓が閉じ、`assets/sprites/player_sheet.png` が上書きされる。出力に「保存しました (OK)」と出れば成功。

クラウド（Godot のエディターがない環境）では次のコマンドで焼けます。

```
xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/render_player/render_player.tscn
```

## モデルを差し替える

- `assets/models/player.glb` を置くと、仮のモデル（`placeholder_wizard.gd`）の代わりにそれを焼きます。
- 足元を原点、正面を +Z（Blender では -Y 前、Godot に取り込むと +Z 前になるよう向きを確かめる）、身長はおよそ 2 単位にしてください。
- glb に `walk` という名前のアニメーションがあれば、その1周を4コマに分けて焼きます。なければ全コマ同じ姿勢です。
- 本番の素材に AI 生成のモデルや画像は使いません（CLAUDE.md）。

## 調整できるところ（`render_player.gd` の先頭）

| 定数 | 意味 |
| --- | --- |
| `CELL` | 1コマの大きさ（ピクセル）。変えたら `player.gd` の `SHEET_CELL` も合わせる |
| `DIRECTIONS` / `FRAMES` | 向きの数と歩きのコマ数。`player.gd` の `SHEET_DIRECTIONS` / `SHEET_FRAMES` と合わせる |
| `FOOT` | コマの中で足元が来る位置。`player.gd` の `SHEET_FOOT` と合わせる |
| `CAMERA_PITCH` | 見下ろす角度（度） |
| `CAMERA_SIZE` | コマの縦に映る広さ（モデルの単位）。小さくするとモデルが大きく映る |
| `OUTLINE_PX` | 縁取りの太さ（ピクセル） |

ゲーム画面での大きさは `player.gd` の `SHEET_PIXEL` と、`data/balance.csv` の `unit_scale` / `player_size_rate` で決まります。

`tools/` は Web 版の書き出しに含めません（`export_presets.cfg` の `exclude_filter`）。
