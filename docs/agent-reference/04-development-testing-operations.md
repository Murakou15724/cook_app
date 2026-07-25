# 開発・テスト・運用ガイド

## 1. この文書の位置づけ

この文書は、開発環境の準備、検証方法、運用上の注意点をまとめた参照資料である。
コマンドを実行する前に、対象環境とデータへの影響を確認すること。特にデータベース変更、外部サービスへの書き込み、コミット以降の Git 操作には人間の明示承認が必要である。

記載区分は次のとおり。

- **実装事実**: リポジトリ内のコードまたは設定で確認できた内容
- **実測結果**: 2026-07-26 までに実行された検証結果
- **未確認**: 調査環境では実機確認できていない内容

基準: コミット済みのcommit `674c39d5882339af3cfa73cebc410d619aebf7fc`と、branch `meal-plan-edit_0726`上の未コミット実装差分およびdocs差分。未コミット差分を基準commitに含まれる変更として扱わない

## 2. 技術構成

| 項目 | 内容 | 区分・根拠 |
|---|---|---|
| Ruby | 3.2.0 | 実装事実: `Gemfile:3`、`Dockerfile:3-5` |
| Rails | 7.1 系 | 実装事実: `Gemfile.lock:191` |
| 画面 | ERB + Turbo + Stimulus | 実装事実: `Gemfile:18-21`、`app/javascript/application.js:1-3`、`app/views/layouts/application.html.erb:16-17` |
| JavaScript 配信 | importmap | 実装事実: `Gemfile:14-15`、`app/views/layouts/application.html.erb:17` |
| テスト | Minitest | 実装事実: `Gemfile:29`、`test/test_helper.rb` |
| development / test DB | MySQL | 実装事実: `config/database.yml:12-29` |
| production DB | `DATABASE_URL` 経由、pg gemをproduction群で使用 | 実装事実: `config/database.yml:51-54`、`Gemfile:45-53` |

## 3. ローカルセットアップと起動

### 3.1 前提

- Ruby 3.2.0
- Bundler
- MySQL
- JavaScript の npm ビルドは不要。importmap で配信する。

### 3.2 提案手順（未実測）

リポジトリ内に、開発環境のセットアップと起動方法を定めた正本手順は確認できない。以下はリポジトリ構成から導いた**提案であり、2026-07-25の調査では一連の手順として実測していない**。データベース作成・migration 実行は承認対象である。

```bash
bundle install
bundle check
bin/rails server
```

`bin/setup`自体は存在するが、依存関係の導入、`db:prepare`、log/tmpの消去、開発サーバーの再起動を行う（`bin/setup:16-32`）。DB作成・migration等を含み得るため、対象DBの確認と人間の明示承認より前には実行しない。

データベース準備が必要な場合は、先に対象環境と実行内容について人間の明示承認を得ること。AI は未承認で `db:create`、`db:migrate`、`db:schema:load`、`db:drop` などを実行しない。

test DBの接続先と隔離を確認し、人間の明示承認を得た後に、まず並列実行を避けた次のコマンドで全Minitestを実行できる。これは標準の実行例であり、2026-07-26の実測結果はseed・run数・assertion数を5章へ記録する。

```bash
PARALLEL_WORKERS=1 bin/rails test
```

### 3.3 環境変数

値はこの文書へ記載しない。コードから参照を確認できる主な変数名のみを示す。

| 変数名 | 用途 | 根拠 |
|---|---|---|
| `DATABASE_URL` | production のDB接続 | `config/database.yml:51-54` |
| `RAILS_MAX_THREADS` | DBコネクションプール | `config/database.yml:15,53` |
| `MYSQL_SOCKET` | development / test のMySQLソケット | `config/database.yml:18` |
| `RAILS_ENV` | Rails実行環境 | `Dockerfile:10-14` |
| `BUNDLE_DEPLOYMENT` | Docker production ビルドのBundler設定 | `Dockerfile:10-14` |
| `BUNDLE_PATH` | Docker内のgem配置先 | `Dockerfile:10-14` |
| `SECRET_KEY_BASE_DUMMY` | asset precompile時の一時設定 | `Dockerfile:36-37` |
| `WEBAUTHN_ALLOWED_ORIGINS` | WebAuthnで許可するorigin | `config/initializers/webauthn.rb:7` |
| `WEBAUTHN_RP_ID` | WebAuthnのRelying Party ID | `config/initializers/webauthn.rb:8` |
| `REDIS_URL` | productionのAction Cable接続先。ただし業務用Channelは未実装 | `config/cable.yml:7-10` |
| `RAILS_MIN_THREADS` | Pumaの最小thread数 | `config/puma.rb:11` |
| `WEB_CONCURRENCY` | Pumaのworker数 | `config/puma.rb:21-23` |
| `PORT` | Pumaの待受port | `config/puma.rb:35` |
| `PIDFILE` | PumaのPIDファイル | `config/puma.rb:41` |
| `RAILS_LOG_LEVEL` | productionのログレベル | `config/environments/production.rb:54-65` |

秘密情報を含む `.env`、暗号鍵、credentials の内容は読み取らず、ログ・Issue・ドキュメントへ転記しない。

## 4. データベース操作の安全ルール

development / test は MySQL、production は `DATABASE_URL` を経由する構成であり、同じSQL・制約がそのまま両方で動作するとは限らない（`config/database.yml:12-29,51-54`、`db/schema.rb:13-170`）。

次の操作は、人間が対象環境・変更内容・復旧方法を確認し、明示承認した後にのみ行う。

- migration の作成・適用
- `db:create`、`db:drop`、`db:schema:load`
- INSERT / UPDATE / DELETE を伴う runner、console、SQL
- 本番・検証DBへの接続と書き込み

調査時は原則としてコード、schema、migrationを読む。DBへ問い合わせる場合も原則 SELECT のみとし、接続先を先に確認する。

## 5. 検証コマンドと2026-07-26の結果

### 5.1 実測済み

| 検証 | 結果 | 判定 |
|---|---|---|
| `test/integration/meal_plans_test.rb`（seed 8849） | 33 runs、301 assertions、0 failures、0 errors、0 skips | 成功 |
| Rails test全体（seed 10885） | 86 runs、641 assertions、0 failures、0 errors、0 skips | 成功 |
| `test/system/meal_plan_edit_test.rb`、Chrome 151（seed 25849） | 4 runs、20 assertions、0 failures、0 errors、0 skips | 成功 |
| Ruby構文確認 | 構文エラーなし | 成功 |
| Node構文確認 | `meal_plan_form_controller.js`の構文エラーなし | 成功 |
| ActionViewによるERB解析 | 変更ERBの解析エラーなし | 成功 |
| Zeitwerk eager load確認 | 定数ロードエラーなし | 成功 |
| `bin/rails routes -c MealPlansController` | コマンドが完了し、MealPlansControllerのroute出力を確認 | 成功 |
| 差分検査 | `git diff --check`でエラーなし | 成功 |

Integration testでは通常編集のID差分同期、所有scope、入力異常、rollback、買い物同期、CookingRecord保護と、作成・quick edit・削除の回帰を確認した。System testではquick edit drawerから通常編集へのtop-level navigation、料理削除確認のCancel/OK、focus移動、keyboard操作、Chrome 151の320px幅を確認した。

テスト根拠: `test/integration/meal_plans_test.rb`; `test/system/meal_plan_edit_test.rb`

routes確認はroute定義を読み込んで出力できることの検証であり、Minitest/System testのrun数・assertion数には含めない。

### 5.2 検証時の環境変更と未確認範囲

- test DBの作成、migration、dropは実行していない。
- System test用のChromeは検証時に`/tmp`へ一時取得しただけで、リポジトリ構成、依存定義、環境変数は変更していない。
- production相当DB・データ量での性能、通常編集とquick editの並行更新、実端末固有の表示・操作差は未確認である。

推奨する検証順序は次のとおり。

1. 変更対象に最も近い単体またはintegration test
2. 関連領域のテスト
3. 全Minitest
4. `bundle check`、Ruby構文、Zeitwerk、routes

## 6. CIと定期アクセス

### 6.1 現状

GitHub Actions で確認できる workflow は Render の `/ping` への定期アクセスである。ジョブはHTTP応答を確認するが、Minitest、lint、静的解析、asset buildは実行しない（`.github/workflows/render_keep_alive.yml:14-24`、`config/routes.rb:69-70`）。

したがって、現状の workflow をアプリケーション変更のCI合否判定として使用できない。

### 6.2 運用上の注意

- `/ping` は常に `200` と `ok` を返すRack endpointであり、DB接続や主要機能の健全性までは検査しない（`config/routes.rb:69-70`）。
- workflow のスケジュールコメントと cron の実際の時間帯には差がある可能性がある。詳細は [drift・リスク・未確認事項](./07-drift-risks-open-questions.md) を参照する。
- テストCIの導入は未実装であり、導入する場合は別Issueで対象環境・DBサービス・必須チェックを確定する。

## 7. Dockerとproduction運用

Dockerfile は multi-stage build、非rootユーザー、asset precompile、Rails server 起動を定義している（`Dockerfile:17-18,36-41,52-62`）。

一方で、次の点は **未確認** である。

- Docker image の実ビルド成功
- コンテナからproduction DBへの接続
- Renderのbuild / start command、環境変数、永続化設定
- デプロイ済みcommitと基準commitの一致
- production上の通常ログイン、パスキー、主要CRUD
- ロールバック手順

また、Dockerのruntime packageにはMySQL clientが含まれる一方、productionはpg gemを使用する構成である（`Dockerfile:43-46`、`Gemfile:45-53`）。これが実際のRender構成に適合するかは確認できていない。

## 8. Job・Mailer・Cable

基底クラスは存在するが、業務用の個別Job・Mailer・Channelは確認できない。

- Job: `app/jobs/application_job.rb:1-7`
- Mailer: `app/mailers/application_mailer.rb:1-4`
- Cable: `app/channels/application_cable/connection.rb:1-4`、`app/channels/application_cable/channel.rb:1-4`

したがって、非同期処理、メール送信、リアルタイム配信を実機能として扱わない。

## 9. 変更時の完了条件

変更担当者は、少なくとも次を記録する。

- 変更対象と受け入れ条件
- 実行した検証コマンド
- 成功・失敗・未実施の区分
- DBや外部サービスを使用したか
- 未確認事項とproduction影響

「コマンドが起動した」「routeが存在する」ことと「業務機能が正常に完了した」ことを区別する。
