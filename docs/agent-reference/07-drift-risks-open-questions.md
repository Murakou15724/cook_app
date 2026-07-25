# Drift・リスク・未確認事項

## 1. 読み方

この文書は、基準commit `accfa21f70818c5e7e4067119a7fabfc72f5c7f1` を2026-07-25に調査した結果として、資料と実装の不一致（drift）、実装上のリスク、調査環境で確認できなかった事項を分離して記録する。

- **Drift**: 文書・コメント・名称と実装が一致しないもの
- **リスク**: 実装事実から問題が起こり得るが、発生を実測していないもの
- **未確認**: コードだけではproduction実態や動作結果を判断できないもの

未確認事項を障害と断定しない。逆に、未実行の検証を成功済みとして扱わない。

## 2. Drift一覧

| ID | 内容 | 根拠 | 影響 | 推奨対応 |
|---|---|---|---|---|
| D-01 | root `README.md` がRails生成時の雛形で、料理アプリのセットアップ・機能・運用を説明していない | `README.md` | 新規参加者やAIが誤った前提で作業しやすい | 本参照資料へのリンクと最小セットアップをroot READMEへ追加する別変更を検討 |
| D-02 | `move_dish` routeは存在するが、controllerは並び替えず「後続issue」と通知するstub | `config/routes.rb:24-27`、`app/controllers/meal_plans_controller.rb:87-89` | routeの存在だけから実装済みと誤認する | 未実装表示を維持し、実装時はIssue・受け入れ条件・テストを追加 |
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

- **事実**: Home、MealPlan一覧、CookingRecord一覧のGETで`migrate_past_meal_plans!`を呼び、CookingRecord作成とMealPlan更新を行う（`app/controllers/home_controller.rb:2-3`、`app/controllers/meal_plans_controller.rb:2-3`、`app/controllers/cooking_records_controller.rb:2-3`、`app/controllers/application_controller.rb:30-56`）。
- **既存防御**: `source_plan_dish_id`の存在確認とunique indexがある（`app/controllers/application_controller.rb:38-40`、`db/schema.rb:42-44`）。
- **リスク**: 同じユーザーの並行GETが双方で非存在確認を通過し、一方がunique違反となる可能性。GETがDBを書き換えるため、監視・prefetch・再読込でも更新が発生する。
- **未確認**: 並行実行時の例外応答、transaction再試行、DBごとの差。
- **提案**: 並行テストを追加し、必要ならロック、upsert、専用POST/Job等を設計する。方式は要件確定後に選ぶ。

### R-05 通常献立編集とquick editの更新方式が異なる

- **事実**: 通常編集は子を全削除して再作成する（`app/controllers/meal_plans_controller.rb:53-72,236-264`）。quick editは既存食材を個別更新・削除しShoppingItemを同期する（同`:100-110,160-210`）。
- **リスク**: 同じ見た目の編集でもID保持、購入状態、関連削除の結果が異なる。
- **未確認**: 全68テストが未実行のため、両経路の現在の実動作。
- **提案**: 仕様として差を許容するか確定し、両経路に同一観点の回帰テストを用意する。

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
- **実測**: 2026-07-25は`bundle check`、Ruby83ファイルの構文、Zeitwerk、routesが成功した。
- **未確認**: `/tmp/mysql.sock`は存在したが、MySQL接続が`ERROR 2002`で失敗した。DB事前確認で停止したためMinitest自体を起動しておらず、68件は未実行。
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
| O-06 | Minitest 68件の合否 | MySQLを利用可能にして全件実行 |
| O-07 | MySQLとPostgreSQLでmigration・検索結果が一致するか | 両DBの隔離test環境で比較 |
| O-08 | 過去献立移行の並行実行結果 | 同一ユーザー・同一献立への並行integration test |
| O-09 | keep-aliveの意図したJST開始・終了時刻 | 運用担当に確認してcronとコメントを照合 |
| O-10 | admin destroy stubと`move_dish`の予定Issue | Issue trackerで確定Issueの有無を確認 |

## 7. 対応優先度の提案

以下は仕様確定ではなく、リスクに基づく提案である。

1. 固定Basic認証情報の失効・外部化、`password_digest`表示要否の確認
2. `/dev/pages`の認可とproduction公開要否の確認
3. Minitestを実行できる環境の復旧とCI導入
4. GET時移行の並行性検証
5. Render/Docker/production DBの実態確認
6. stub機能の表示・Issueとの対応付け
7. root READMEとkeep-aliveコメントのdrift解消

いずれも実装修正はdeveloperが担当し、Issue確定・実装開始・必要なDB/外部操作の承認ゲートを通す。
