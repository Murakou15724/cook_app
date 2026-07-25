# AI エージェント向けリポジトリ参照資料

## 1. このフォルダの目的

このフォルダは、AI エージェントと開発者が毎回リポジトリ全体を読み直さずに、cook_app の現行実装、変更時の影響範囲、安全な作業手順を把握するための索引である。

- 基準コミット: `accfa21f70818c5e7e4067119a7fabfc72f5c7f1`
- 調査日: 2026-07-25
- 記載区分:
  - **実装事実**: コードまたは schema から確認できる内容
  - **テスト期待**: Minitest に記載されている期待。未実行の場合は動作確認済みを意味しない
  - **リスク・推測**: 実装から推測できる懸念。仕様として確定しない
  - **未確認**: 実機、外部サービス、DB 接続などの確認を完了していない内容

## 2. 文書一覧

| 文書 | 用途 |
|---|---|
| [01-system-overview.md](01-system-overview.md) | システムの目的、技術構成、ディレクトリ、責務境界を把握する |
| [02-functional-specification.md](02-functional-specification.md) | 利用者、画面・route、主要ユースケース、実装済み機能と stub を確認する |
| [03-architecture-and-data.md](03-architecture-and-data.md) | 認証、処理フロー、ER、モデル制約、削除連鎖を確認する |
| [04-development-testing-operations.md](04-development-testing-operations.md) | setup、起動、環境変数、テスト、デプロイ、運用方法を確認する |
| [05-agent-work-guide.md](05-agent-work-guide.md) | AI チームの役割、承認 Gate、安全な標準手順を確認する |
| [06-change-impact-map.md](06-change-impact-map.md) | 機能から主なコード・テスト・影響先へ最短でたどる |
| [07-drift-risks-open-questions.md](07-drift-risks-open-questions.md) | 文書と実装の不一致、stub、セキュリティリスク、未確認事項を確認する |

## 3. タスク別の読み方

| タスク | 最初に読む文書 | 続けて読む文書 |
|---|---|---|
| 初めて全体を把握する | 本 README | [01](01-system-overview.md) → [02](02-functional-specification.md) → [03](03-architecture-and-data.md) |
| 機能を修正する | [06](06-change-impact-map.md) | [02](02-functional-specification.md)、対象コード、対象テスト |
| DB・関連削除を変更する | [03](03-architecture-and-data.md) | [04](04-development-testing-operations.md)、[05](05-agent-work-guide.md)、migration、`db/schema.rb` |
| 認証・管理画面を変更する | [02](02-functional-specification.md) | [03](03-architecture-and-data.md)、[07](07-drift-risks-open-questions.md) |
| テスト・デプロイ・障害対応 | [04](04-development-testing-operations.md) | [06](06-change-impact-map.md)、[07](07-drift-risks-open-questions.md) |
| AI エージェントが作業を開始する | [05](05-agent-work-guide.md) | [06](06-change-impact-map.md)、[07](07-drift-risks-open-questions.md) |
| 文書を更新する | 本 README | [07](07-drift-risks-open-questions.md) と変更対象の設計文書 |

## 4. 根拠の優先順位

この資料は理解を速めるための二次資料であり、**コード、migration、schema、実測結果が最終根拠**である。文書とコードが異なる場合、文書に合わせて実装を勝手に変更せず、[07-drift-risks-open-questions.md](07-drift-risks-open-questions.md) に drift として記録する。

確認時の優先順位は次のとおり。

1. 確定した Issue・受け入れ条件
2. 対象コード、migration、`db/schema.rb`
3. 実行済みテストの結果
4. テストコードに記載された期待
5. 本フォルダおよび root `README.md`

重要事項には `file:line` とクラス・メソッド名を記載している。行番号がずれている場合は、併記したクラス名・メソッド名で検索する。

## 5. 鮮度と更新ルール

次の変更を行ったときは、同じ作業単位で該当文書を更新する。

- route、画面、利用者権限、認証方式の変更
- controller の主要フロー、モデル関連、validation、transaction の変更
- migration、schema、DB adapter、削除連鎖の変更
- setup、環境変数名、テストコマンド、デプロイ・監視方法の変更
- stub の実装または新しい未確認事項・リスクの発見
- AI チームの役割、承認 Gate、安全規約の変更

更新時は以下を実施する。

1. 基準コミットと調査日を更新する。
2. 実装事実、テスト期待、リスク、未確認を混在させない。
3. 根拠の `file:line` を更新する。
4. [06-change-impact-map.md](06-change-impact-map.md) と [07-drift-risks-open-questions.md](07-drift-risks-open-questions.md) への影響を確認する。
5. 本 README から全資料へ到達でき、相互リンクが切れていないことを確認する。

## 6. 安全上の注意

- 認証情報、暗号鍵、環境変数の値、seed の実データは読み取ったり転記したりしない。
- DB 変更、コミット、push、PR、外部書き込みは [05-agent-work-guide.md](05-agent-work-guide.md) の承認 Gate に従う。
- GET リクエストでも過去献立の履歴化により DB 更新が起こる画面がある。詳細は [03-architecture-and-data.md](03-architecture-and-data.md) を参照する。
