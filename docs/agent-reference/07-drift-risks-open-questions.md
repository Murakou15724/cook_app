# Drift・リスク・未確認事項

## 1. 読み方

この文書は、コミット済みのcommit `674c39d5882339af3cfa73cebc410d619aebf7fc`と、branch `meal-plan-edit_0726`上の未コミット実装差分およびdocs差分を2026-07-26に調査した結果として、資料と実装の不一致（drift）、実装上のリスク、調査環境で確認できなかった事項を分離して記録する。未コミット差分を基準commitに含まれる変更として扱わない。

- **Drift**: 文書・コメント・名称と実装が一致しないもの
- **リスク**: 実装事実から問題が起こり得るが、発生を実測していないもの
- **未確認**: コードだけではproduction実態や動作結果を判断できないもの

未確認事項を障害と断定しない。逆に、未実行の検証を成功済みとして扱わない。

## 2. Drift一覧

### 2.1 今回解消したdrift

| ID | 旧記述・不足 | 実装事実 | 対応 |
|---|---|---|---|
| RD-01 | 通常献立編集が`PlanDish`以下を全削除・再作成すると記載されていた | hidden IDによるtransaction内差分同期へ変更され、未変更レコードは書き込まない | [機能仕様](02-functional-specification.md#43-通常献立編集と-quick-edit-の違い)、[アーキテクチャとデータ](03-architecture-and-data.md#32-通常献立編集の差分同期)、[変更影響マップ](06-change-impact-map.md#41-献立通常編集)を更新 |
| RD-02 | quick edit drawerから通常編集へ進む導線が記載されていなかった | `data-turbo-frame="_top"`の「献立全体を編集」リンクを実装 | 機能仕様、変更影響マップへ画面導線とSystem test根拠を追加 |
| RD-03 | MySQL接続不能によりMinitest 68件未実行と記載されていた | 2026-07-26に対象Integration 33件、Rails全86件、System 4件がすべて成功 | 機能仕様、開発・テスト・運用ガイド、変更影響マップ、リスク記録を実測へ更新 |
| RD-04 | 本フォルダのREADMEが旧commit・旧調査日のままで、コミット済み基準と未コミット差分の境界が不明確だった | コミット済み基準は`674c39d5882339af3cfa73cebc410d619aebf7fc`、追加確認対象はbranch `meal-plan-edit_0726`上の未コミット実装/docs差分、調査・検証日は2026-07-26 | [README](README.md)と基準情報を持つ文書を現行化し、未コミット差分を基準commitに含めないと明記 |
| RD-05 | `MealPlansController`への一部`file:line`根拠がcontroller増分により旧位置を指していた | 現行コードのクラス・メソッドを再照合 | 01/02/03/06/07の該当根拠を`Class#method`中心へ置換 |
| RD-06 | routes成功の記録が一般的な「routes確認」に留まり、テスト件数との区分も明示されていなかった | 2026-07-26に`bin/rails routes -c MealPlansController`が成功 | 実行コマンドと結果を記載し、Minitest/System testのrun・assertion数に含まないと明記 |

### 2.2 残存drift

| ID | 内容 | 根拠 | 影響 | 推奨対応 |
|---|---|---|---|---|
| D-01 | root `README.md` がRails生成時の雛形で、料理アプリのセットアップ・機能・運用を説明していない | `README.md` | 新規参加者やAIが誤った前提で作業しやすい | 本参照資料へのリンクと最小セットアップをroot READMEへ追加する別変更を検討 |
| D-02 | `move_dish` routeは存在するが、controllerは並び替えず「後続issue」と通知するstub | `config/routes.rb:24-27`、`MealPlansController#move_dish` | routeの存在だけから実装済みと誤認する | 未実装表示を維持し、実装時はIssue・受け入れ条件・テストを追加 |
| D-03 | admin側のMealPlan、CookingRecord、ShoppingItem、PersonTagのdestroy routeは存在するが、実データを削除しないstub | `config/routes.rb:58-61`、`app/controllers/admin/meal_plans_controller.rb:9-10`、`app/controllers/admin/cooking_records_controller.rb:9-10`、`app/controllers/admin/shopping_items_controller.rb:9-10`、`app/controllers/admin/person_tags_controller.rb:9-10` | 管理者が削除できると誤認する | 画面文言・テスト期待を確認し、実装は別Issueで扱う |
| D-04 | keep-aliveコメントは「JST 6:00〜23:50」と説明するが、cronは毎時7〜57分の10分間隔であり、境界の表現が一致しない | `.github/workflows/render_keep_alive.yml:4-8` | 運用担当が最初・最後のping時刻を誤認する | UTC/JSTの実時刻表を確定し、コメントかcronを合わせる |
| D-05 | productionはpg gemと`DATABASE_URL`を使う一方、Docker runtimeはMySQL clientを導入している | `Gemfile:45-53`、`config/database.yml:51-54`、`Dockerfile:43-46` | image内ツールと実DBの前提が一致しない可能性 | Render実設定を確認後、必要なclient packageを確定 |
| D-06 | Job・Mailer・Cableの基底は存在するが、業務機能は存在しない | `app/jobs/application_job.rb:1-7`、`app/mailers/application_mailer.rb:1-4`、`app/channels/application_cable/channel.rb:1-4` | Rails標準ディレクトリの存在から機能実装済みと誤認する | 機能一覧では「未使用」と明記し、実装時に文書更新 |

## 3. セキュリティ・権限リスク

### R-01 固定Basic認証情報

- **事実**: 管理者登録controllerのBasic認証情報がコード中の固定値として定義されている（`app/controllers/admin/registrations_controller.rb:3`）。
- **機密保護**: 値そのものはこの文書へ記載しない。
- **リスク**: リポジトリ閲覧者に認証情報が知られる、環境別ローテーションができない。
- **提案**: credentialsまたは環境変数へ移し、既存値を失効させる。実施には確定Issueと、production設定を変更する場合は外部書き込み承認が必要。

### R-02 管理者画面でpassword_digestを表示

- **事実**: adminユーザー詳細画面は`password_digest`をHTMLへ出力する（`app/views/admin/users/show.html.erb:14-16`）。
- **リスク**: ハッシュの漏えい、画面共有・ログ収集・ブラウザ拡張等を経由した不要な露出。
- **提案**: 表示要件を人間が確認し、不要なら非表示化するIssueを作成する。

### R-03 `/dev/pages`が一般ログインで到達可能

- **事実**: routeは通常namespaceにあり、controllerのguardは`authenticate_user!`だけで`require_admin!`がない（`config/routes.rb:19-21`、`app/controllers/dev_pages_controller.rb:1-10`）。
- **補足**: layout上のリンクはadminだけに表示されるが、URL直アクセスの認可とは異なる（`app/views/layouts/application.html.erb:33-38`）。
- **リスク**: memberが開発用情報・他ユーザー由来データへ到達する可能性。
- **提案**: 本番公開要否と対象ロールを確定し、不要なら環境制限またはadmin制限をIssue化する。

## 4. データ整合性・並行性リスク

### R-04 GETリクエストが過去献立を移行する

- **事実**: `HomeController`, `MealPlansController`, `CookingRecordsController`のindexに対するbefore_actionで`ApplicationController#migrate_past_meal_plans!`を呼び、CookingRecord作成とMealPlan更新を行う。
- **既存防御**: `source_plan_dish_id`の存在確認とunique indexがある（`app/controllers/application_controller.rb:38-40`、`db/schema.rb:42-44`）。
- **リスク**: 同じユーザーの並行GETが双方で非存在確認を通過し、一方がunique違反となる可能性。GETがDBを書き換えるため、監視・prefetch・再読込でも更新が発生する。
- **未確認**: 並行実行時の例外応答、transaction再試行、DBごとの差。
- **提案**: 並行テストを追加し、必要ならロック、upsert、専用POST/Job等を設計する。方式は要件確定後に選ぶ。

### R-05 通常献立編集とquick editの並行更新（Low）

- **事実**: 通常編集は`MealPlansController#sync_full_update!`内でactive献立をlockしてID差分同期する。quick editは`#quick_update`内の別transactionで料理・食材・人物タグを更新する。
- **既存防御**: 両経路ともログインユーザー所有かつactiveの献立にscopeされ、nested IDも対象献立内に限定される。通常編集単独のrollbackと同一内容再送、quick editの回帰はIntegration testで成功した。
- **リスク**: 同じ献立へ通常編集とquick editを同時送信した場合、後から実行された更新が先の変更を上書きする、または通常編集の送信内容から除外されたデータを削除する可能性がある。
- **未確認**: full/quick updateを意図的に並行実行した結果、lock待ち、最終状態、利用者への競合通知。
- **提案**: 現状はLowリスクとして記録し、必要性が高まった場合に並行Integration testと楽観locking等の要否を別Issueで検討する。

## 5. DB・デプロイ・運用リスク

### R-06 development/testとproductionのDB二系統

- **事実**: development/testはMySQL（`config/database.yml:12-29`）。productionは`DATABASE_URL`とpg gemを使用する（`config/database.yml:51-54`、`Gemfile:45-53`）。
- **リスク**: SQL構文、照合順序、大文字小文字、check constraint、LIKEの挙動が環境間で異なる。
- **未確認**: 全migrationがPostgreSQLで適用できること、production schemaが`db/schema.rb`と一致すること。
- **提案**: CIまたは検証環境でproduction相当DBのmigration・テスト経路を設ける。

### R-07 DockerとRender経路

- **事実**: Dockerfileはproduction imageとRails server起動を定義する（`Dockerfile:10-14,17-18,36-41,52-62`）。GitHub Actionsは公開URLの`/ping`へアクセスする（`.github/workflows/render_keep_alive.yml:14-24`）。
- **未確認**: RenderがこのDockerfileを使用しているか、build/start command、環境変数、DB、デプロイ済みcommit、ロールバック方法。
- **リスク**: リポジトリ上の想定と実際のホスティング設定が乖離していても検知できない。
- **提案**: 値を転記せず、Render dashboardの設定項目名とデプロイ経路だけを運用確認する。

### R-08 アプリケーションCIがない

- **事実**: 確認できたGitHub Actions workflowは`/ping`ジョブであり、test/lint/buildは実行しない（`.github/workflows/render_keep_alive.yml:14-24`）。
- **テスト実測**: 2026-07-26は対象Integration 33 runs / 301 assertions、Rails全体86 runs / 641 assertions、Chrome 151のSystem 4 runs / 20 assertionsが、failure・error・skipなしで成功した。
- **非テスト検証**: Ruby構文、Node構文、ERB解析、Zeitwerk、差分検査が成功した。`bin/rails routes -c MealPlansController`も成功し、MealPlansControllerのroute出力を確認した。
- **環境変更**: test DBの作成・migration・dropは実行していない。Chromeは`/tmp`へ一時取得しただけで、リポジトリ構成は変更していない。
- **リスク**: 変更をpushしても自動回帰テストがなく、DB依存の不具合を検出できない。
- **提案**: MySQL serviceを含むMinitest CIと、最低限の構文・Zeitwerk検証を別Issueで設計する。

### R-09 `/ping`の検査範囲が狭い

- **事実**: `/ping`はDBやRails controllerを介さず固定レスポンスを返す（`config/routes.rb:69-70`）。
- **リスク**: DB接続不能、認証障害、主要画面障害でもkeep-aliveが成功する可能性。
- **提案**: keep-aliveとhealth checkの目的を分け、必要ならread-onlyの健全性確認を設計する。

## 6. 未確認事項一覧

| ID | 未確認事項 | 確認方法の候補 |
|---|---|---|
| O-01 | productionで稼働しているcommit | Renderのdeploy履歴とGit SHAを照合 |
| O-02 | production DBの製品・version・schema | 値を記録せず管理画面とread-onlyメタデータで確認 |
| O-03 | Dockerfileが実デプロイ経路で使われるか | Renderのruntime/build設定を確認 |
| O-04 | production環境変数が必要分揃うか | 変数名と設定有無のみ確認し、値は読まない |
| O-05 | 通常ログイン、パスキー、主要CRUDのproduction動作 | 承認済みテストアカウントと非破壊シナリオで確認 |
| O-06 | production相当データ量での通常献立編集性能 | 隔離したproduction相当環境で料理・食材・買い物項目が多い献立の応答時間とquery/write数を計測 |
| O-07 | MySQLとPostgreSQLでmigration・検索結果が一致するか | 両DBの隔離test環境で比較 |
| O-08 | 過去献立移行の並行実行結果 | 同一ユーザー・同一献立への並行integration test |
| O-09 | keep-aliveの意図したJST開始・終了時刻 | 運用担当に確認してcronとコメントを照合 |
| O-10 | admin destroy stubと`move_dish`の予定Issue | Issue trackerで確定Issueの有無を確認 |
| O-11 | 通常編集とquick editの並行更新結果 | 同一active献立へのfull/quick updateを並行実行し、最終状態と競合通知を確認 |
| O-12 | 320px実端末固有の表示・keyboard・focus挙動 | 承認済み実端末で非破壊シナリオを確認。Chrome 151の320px System testは成功済み |

## 7. 対応優先度の提案

以下は仕様確定ではなく、リスクに基づく提案である。

1. 固定Basic認証情報の失効・外部化、`password_digest`表示要否の確認
2. `/dev/pages`の認可とproduction公開要否の確認
3. 成功済みMinitest/System testを継続実行するCIの導入
4. GET時移行の並行性検証
5. Render/Docker/production DBの実態確認
6. stub機能の表示・Issueとの対応付け
7. root READMEとkeep-aliveコメントのdrift解消
8. 必要性に応じた通常編集のproduction相当性能、full/quick並行更新、実端末差の確認

いずれも実装修正はdeveloperが担当し、Issue確定・実装開始・必要なDB/外部操作の承認ゲートを通す。
