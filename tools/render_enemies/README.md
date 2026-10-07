# 敵の絵を3Dモデルから焼く

敵（スライム・突進スライム・ボス・森の木）は、主人公と同じく3Dモデルをあらかじめ絵に焼いて表示しています。
ゲームの中では3Dを使わず、焼いた絵を向きと動きに合わせて切り出して描くだけなので、敵が大量に出ても重くなりません。
切り出しは `scripts/draw/sprite_sheet.gd`、使う側は `scenes/slime/slime.gd`・`scenes/dasher/dasher.gd`・`scenes/boss/boss.gd`・`scenes/oak/oak.gd` です。

## 焼き直す手順

1. Godot 4.5 でこのプロジェクトを開く。
2. `tools/render_enemies/render_enemies.tscn` を開き、「現在のシーンを実行」（F6）を押す。
3. 数秒で窓が閉じ、`assets/sprites/enemies/` の絵が上書きされる。出力に「保存しました (OK)」が並べば成功。

クラウド（Godot のエディターがない環境）では次のコマンドで焼けます。

```
xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/render_enemies/render_enemies.tscn
```

## 焼く絵

| ファイル | 中身 | 向き×コマ |
| --- | --- | --- |
| `slime.png` | 青いスライム（うろついているとき） | 8×4 |
| `slime_angry.png` | 赤い怒り顔のスライム（追ってきているとき） | 8×4 |
| `dasher.png` | 角のある橙色の突進スライム | 8×4 |
| `dasher_windup.png` | 黄色い怒り顔の突進スライム（予備動作と突進のあいだ） | 8×4 |
| `boss.png` | 王冠をかぶった紫のスライム | 8×4 |
| `oak.png` / `oak_regen.png` | 森の木（ふだん／耐久が戻っているあいだ） | 1×1 |

行が向き（画面の右から時計回りに45度ずつ）、列が跳ねる動きのコマです。一覧は `render_enemies.gd` の `JOBS`。

## モデルを差し替える

- `assets/models/<ファイル名>.glb`（例: `slime.glb`）を置くと、仮のモデル（`placeholder_monster.gd`）の代わりにそれを焼きます。
- 足元を原点、正面を +Z にしてください。glb に `walk` という名前のアニメーションがあれば、その1周をコマに分けて焼きます。
- 本番の素材に AI 生成のモデルや画像は使いません（CLAUDE.md）。

ゲーム画面での大きさは各スクリプトの `SHEET_PIXEL` と、`data/balance.csv` の `unit_scale` で決まります。
`JOBS` の向きの数・コマ数・`foot` を変えたら、使う側の `SHEET_*` も合わせてください。

`tools/` は Web 版の書き出しに含めません（`export_presets.cfg` の `exclude_filter`）。
