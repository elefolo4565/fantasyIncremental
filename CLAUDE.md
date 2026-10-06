# CLAUDE.md

このリポジトリは、ファンタジー世界のアクション×インクリメンタルゲーム（Astro Prospector 風、見た目はブロスタ風の2D）の試作です。
実装は主に AI が行い、人はスマホから修正を依頼して Web 版で試遊します。このファイルは実装時に必ず守るルールです。

## 技術の前提

- エンジンは **Godot 4.5**、言語は **GDScript** だけを使う（C# や GDExtension は使わない）。
- 書き出し先は **Web（シングルスレッド版）**。レンダラーは **Compatibility**（`gl_compatibility`）に固定する。
  - スレッド、`OS.execute`、ファイルの書き込み先を前提にした処理など、Web で動かない機能は使わない。
- 操作は**タッチが基本**。左半分に仮想スティック（`scenes/ui/virtual_stick.gd`）、右側にスキルボタン、攻撃は自動。
  PC での確認用にキーボード（矢印・WASD）とマウスのドラッグでも動くようにしておく。
- 画面の基準サイズは 1280×720、`canvas_items` + `expand` で伸縮する。座標を決め打ちせず `get_viewport_rect()` を使う。

## フォルダ構成

```
data/                 調整用の数値（CSV）。人が直接編集する
scenes/<名前>/        1つのシーンと、そのスクリプトを同じフォルダに置く（例: scenes/slime/slime.tscn, slime.gd）
scripts/autoload/     オートロード（Balance など）
.github/workflows/    Web 版のビルドと GitHub Pages への公開
```

## 数値はすべてデータファイルに置く（最重要）

- 速度、間隔、耐久、ダメージ、数、時間、価格、確率など、**ゲームの手触りやバランスに関わる数値はスクリプトに書かない**。
  `data/*.csv` に置き、`Balance.get_float("key")` / `Balance.get_int("key")` で読む。
- CSV は `key,value,memo` の3列。新しいキーを足すときは **memo に日本語で「何の数値か・単位」を必ず書く**。
- 見た目だけの定数（図形の半径、色、余白など）はスクリプト先頭の `const` に置いてよい。
- 表形式のデータ（強化ノード一覧、敵の種類など）が必要になったら、1行1項目の CSV を `data/` に新しく作る。
  新しい CSV は `<ファイル名>.csv.import` に `importer="keep"` を書いて、翻訳ファイルとして取り込まれないようにする。
  `export_presets.cfg` の `include_filter="data/*.csv"` で書き出しに含まれる。

## コードの書き方

- Godot 4 の公式スタイルガイドに従う。インデントはタブ、ファイル名とフォルダ名は `snake_case`、`class_name` は `PascalCase`。
- 変数・引数・戻り値には型を付ける（`var speed := 0.0`、`func take_hit(damage: int) -> void:`）。
- **シーンは小さく、1つの役割だけ**を持たせる。シーン同士は `signal` でつなぎ、親が子を直接操作する方向にする（子から `get_parent()` で親をいじらない。生成した弾を同じ階層に足す程度は可）。
- 壊せる物（モンスター・木など）は基底クラス `Breakable` を継承し、グループ `Breakable.GROUP`（`&"breakable"`）に入れる。
- スクリプト先頭に `##` で「このシーンは何をするか」を1〜3行で書く。
- 画面の文字は日本語でよい。フォントは `assets/fonts/MPLUSRounded1c-ExtraBold-subset.ttf`（OFL。`scenes/main/main.gd` で既定テーマの `default_font` と `ThemeDB.fallback_font` に設定している。PC では OS のフォントで補われて気づけないので、Web で文字化けしていないか確かめる。`gui/theme/custom_font` は CI の初回インポートでエラーになるので使わない）。
  ASCII・かな・記号・JIS第1水準の漢字だけに絞ってあるので、第2水準の漢字（例: 「呪」「贄」など）を使うと表示されない。使いたいときは元のフォントから作り直す。

## ゲームデザインのルール

- 強化（魔導樹・精霊の輪）は、**「倒すのに必要な攻撃回数が変わる」か「挙動が変わる」かのどちらか**に限る。
  魔導樹の画面では「何発で壊れるようになるか」を見せる。プレイ中の敵の体力は、減ったときだけバーで出し数字は出さない（与えたダメージは短く数字で出す）。
  例外として、ラン1回の活動時間（Hourglass）・攻撃間隔（Quick Cast）・射程（Far Sight）・素材の回収範囲（引き寄せ）を伸ばす強化は置いてよい。
  最初の攻撃は攻撃速度・射程・威力とも極めて貧弱にし、成長を楽しむ余地を大きく取る（開始時の活動時間は15秒）。
- 各ステージは決まった数を倒すとボスが出て、ボスを倒すとクリア（ランもそこで終わる）。倒した敵は素材を落とし、拾ったぶんだけ手に入る。
- 1ランは1つの世界で完結し、1〜3分で終わる長さにする。
- 本番用の素材に AI 生成画像は使わない。試作中は `_draw()` の図形や仮の素材で済ませる。

## 開発の流れ

1. 作業ごとにブランチを切り、PR を出す。
2. PR では GitHub Actions（`.github/workflows/web.yml`）が次を自動で行う。
   - プロジェクトの取り込み → メインシーンをヘッドレスで数秒動かす → Web 版を書き出す。
   - ログに `SCRIPT ERROR` / `Parse Error` / `ERROR` が出たら失敗にする。
3. main にマージすると Web 版が GitHub Pages に公開される: https://elefolo4565.github.io/fantasyIncremental/
4. スマホで試遊して、次の修正を依頼する。

Claude のクラウド環境には Godot が入っていないため、**動作確認は PR の CI で行う**。
CI が赤なら、ログを読んで原因を直してから push し直す。

## やらないこと

- `.godot/` や `build/` をコミットしない（`.gitignore` 済み）。
- テストを消したり CI のチェックを緩めたりして通さない。
- Godot のバージョンを上げるときは `project.godot` の `config/features` と `web.yml` の `GODOT_VERSION` を同時に変える。
