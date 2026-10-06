# 音の素材

BGM と効果音は **魔王魂**（森田交一）の素材を使っています。

- クレジット: 音楽・効果音：魔王魂 https://maou.audio/
- 利用規約: https://maou.audio/rule/ （クレジット表記で商用ゲームにも無料で使え、表記すれば二次配布も可。ファイル名に maoudamashii を含めるよう求められているので含めている）
- 2026-10-06 ユーザーの素材フォルダ（C:\_sozai\音楽）から取り込み、ユーザーが「魔王魂で進める」と決定

| ファイル | 元の素材 | 使う場面 |
| --- | --- | --- |
| bgm_tree_maoudamashii_8bit06.ogg | ファミコン風 8bit06（ループ版） | 魔導樹 |
| bgm_battle_maoudamashii_8bit07.ogg | ファミコン風 8bit07（ループ版） | 戦闘 |
| bgm_boss_maoudamashii_8bit05.ogg | ファミコン風 8bit05（ループ版） | ボス |
| se/se_boss_break_maoudamashii_battle_explosion05.ogg | maou_se_battle_explosion05 | boss_break |
| se/se_break_maoudamashii_8bit16.ogg | maou_se_8bit16 | break（2026-10-06 爆発音から軽い音に変更） |
| se/se_buy_maoudamashii_system03.ogg | maou_se_system03 | buy |
| se/se_clear_maoudamashii_jingle04.ogg | maou_se_jingle04 | clear |
| se/se_click_maoudamashii_system24.ogg | maou_se_system24 | click |
| se/se_deny_maoudamashii_system25.ogg | maou_se_system25 | deny |
| se/se_hit_maoudamashii_battle14.ogg | maou_se_battle14 | hit |
| se/se_hurt_maoudamashii_battle12.ogg | maou_se_battle12 | hurt |
| se/se_pickup_maoudamashii_system18.ogg | maou_se_system18 | pickup |
| se/se_ring_maoudamashii_magic_ice02.ogg | maou_se_magic_ice02 | ring |
| se/se_shot_maoudamashii_magical19.ogg | maou_se_magical19 | shot |
| se/se_timeup_maoudamashii_jingle06.ogg | maou_se_jingle06 | timeup |

変換: モノラル 32kHz の Ogg Vorbis にした。効果音は頭の無音を削り、ピークを -1dB にそろえた。音の中身は加工していない。
使う場面と音の対応は scripts/autoload/sfx.gd と bgm.gd。

購入した音楽パック（AlkaKrab など）は「そのままの再配布禁止・オープンソースは要相談」の規約なので、公開リポジトリには置かない。
