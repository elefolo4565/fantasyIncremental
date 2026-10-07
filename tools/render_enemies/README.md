# 敵の絵を3Dモデルから焼く

敵（data/enemies.csv の全種類）と森の木は、主人公と同じく3Dモデルをあらかじめ絵に焼いて表示しています。
ゲームの中では3Dを使わず、焼いた絵を向きと動きに合わせて切り出して描くだけなので、敵が大量に出ても重くなりません。
切り出しは `scripts/draw/sprite_sheet.gd`、使う側は `scenes/monster/monster.gd`（敵）と `scenes/oak/oak.gd`（木）です。

## 新しい敵を足す

1. `data/enemies.csv` に1行足す。
   - `move` は動きの部品（`scenes/monster/moves/`）: `wander_chase`（うろつき、近づくと追う）・`dash`（予備動作のあと突進）・`chase`（いつも追う、ボス向け）
   - `size` は体の半径（当たり判定）、`hp_rate`・`gem_rate`・`speed_rate` はステージの基準（stages.csv の `enemy_*`・ボスなら `boss_*`）に掛ける倍率
   - `model` は仮モデルの形（`slime`・`dasher`・`king`）、`color`・`angry_color` は体の色（16進）
2. 下の手順で焼き直す（`<id>.png`・`<id>_angry.png`・金色になれる敵は `<id>_golden.png` ができる）。
3. `data/stages.csv` の `enemies` に `<id>:数` を足す（`|` でつなぐ）。ボスにするなら `boss` 列に id を書く。

新しい動きが要るときは、`MonsterMove` を継承した部品を `scenes/monster/moves/` に置き、`monster_move.gd` の `create` に名前を足します。部品の数値は `data/balance.csv` に置きます。

## 焼き直す手順

1. Godot 4.5 でこのプロジェクトを開く。
2. `tools/render_enemies/render_enemies.tscn` を開き、「現在のシーンを実行」（F6）を押す。
3. 数秒で窓が閉じ、`assets/sprites/enemies/` の絵が上書きされる。出力に「保存しました (OK)」が並べば成功。

クラウド（Godot のエディターがない環境）では次のコマンドで焼けます。

```
xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/render_enemies/render_enemies.tscn
```

絵は行が向き（画面の右から時計回りに45度ずつ、8方向）、列が跳ねる動きのコマ（4コマ）です。木は向き1つ・1コマ（`EXTRA_JOBS`）。

## モデルを差し替える

- `assets/models/<ファイル名>.glb`（例: `slime.glb`・`slime_angry.glb`）を置くと、仮のモデル（`placeholder_monster.gd`）の代わりにそれを焼きます。
- 足元を原点、正面を +Z にしてください。glb に `walk` という名前のアニメーションがあれば、その1周をコマに分けて焼きます。
- 本番の素材に AI 生成のモデルや画像は使いません（CLAUDE.md）。

ゲーム画面での大きさは `monster.gd` の `SHEET_PIXEL`、`enemies.csv` の `size`、`data/balance.csv` の `unit_scale` で決まります。
向きの数・コマ数・足元の位置（`render_enemies.gd` の `DIRECTIONS`・`FRAMES`・`FOOT`）を変えたら、`monster.gd` の `SHEET_*` も合わせてください。

`tools/` は Web 版の書き出しに含めません（`export_presets.cfg` の `exclude_filter`）。
