# 機能仕様

## 1. 記載区分

- **実装済み**: controller、model、view、route から処理を確認できる。
- **テスト期待あり**: Minitest に期待があるが、2026-07-25 時点では MySQL 接続不能のため suite は未実行。
- **stub**: route/action は存在するが、対象処理を行わず案内して戻る。
- **未確認**: 外部環境・実端末での確認が必要。

## 2. 利用者種別

| 種別 | できること | 認可根拠 |
|---|---|---|
| 未ログイン | 一般ユーザー登録、通常ログイン、パスキーログイン、管理者登録ページへの Basic 認証 | `config/routes.rb:7-17,48-49`; `UsersController#require_no_login!`; `SessionsController#require_no_login!` |
| 一般ユーザー (`member`) | 自分の献立、買い物、過去料理、人物タグ、プロフィール、パスキーを操作 | `app/controllers/application_controller.rb:14-18`; 各 controller の `current_user` scope |
| 管理者 (`admin`) | 一般機能に加え、管理 dashboard、全ユーザー・全データ参照、ユーザー削除 | `app/controllers/admin/base_controller.rb:1-5`; `app/controllers/admin/users_controller.rb:5-57` |

### 注意

- `/dev/pages` は名前に反して environment 制限や admin 制限がなく、ログイン済み一般ユーザーも到達できる実装である。`config/routes.rb:21`; `app/controllers/dev_pages_controller.rb:1-10`
- 管理者新規登録だけは通常の admin session 認可とは別に、コード内で設定された固定 Basic 認証を使用する。値は本資料へ記載しない。`app/controllers/admin/registrations_controller.rb:2-4`

## 3. 画面・route 一覧

### 3.1 認証・設定

| route | method | 画面・処理 | 状態 |
|---|---|---|---|
| `/signup` | GET/POST | 一般ユーザー登録 | 実装済み |
| `/users` | POST | 一般ユーザー登録の別 route | 実装済み |
| `/login` | GET/POST | email/password ログイン | 実装済み |
| `/logout` | DELETE | session 破棄 | 実装済み |
| `/passkey/login/options` | POST | WebAuthn 認証 options | 実装済み、実端末未確認 |
| `/passkey/login` | POST | パスキーログイン | 実装済み、実端末未確認 |
| `/passkeys/options` | POST | ログイン中ユーザーの登録 options | 実装済み、実端末未確認 |
| `/passkeys` | POST | パスキー登録 | 実装済み、実端末未確認 |
| `/profile/edit`, `/profile` | GET, PATCH/PUT | email、nickname、password 更新 | 実装済み |
| `/settings` | GET | profile、人物タグ、登録済みパスキーへの入口 | 実装済み |
| `/dev/pages` | GET | 画面一覧 | 実装済み。一般ログインでも可 |

根拠: `config/routes.rb:7-21`; `app/controllers/users_controller.rb:4-23`; `app/controllers/sessions_controller.rb:4-22`; `app/controllers/passkey_registrations_controller.rb:4-58`; `app/controllers/passkey_sessions_controller.rb:4-53`

### 3.2 一般ユーザー機能

| route 群 | 主な画面・処理 | 状態 |
|---|---|---|
| `/` | 今日の昼食・夕食を表示 | 実装済み |
| `/meal_plans` | 今日以降の献立一覧、作成、通常編集、quick edit、削除 | 実装済み |
| `/meal_plans/:id/move_dish` | 料理の並び替え | **stub** |
| `/shopping_items` | 献立由来と手動の買い物項目を表示・追加・編集・削除 | 実装済み |
| `/shopping_items/:id/toggle_purchased` | 購入済み状態を切り替える | 実装済み |
| `/shopping_items/reorder` | 未購入項目を並び替える | 実装済み |
| `/shopping_items/destroy_purchased` | 自分の購入済み項目を一括削除 | 実装済み |
| `/cooking_records` | 過去料理の検索・表示、手動外食登録 | 実装済み |
| `/cooking_records/:id` | 詳細・編集・削除 | 実装済み |
| `/person_tags` | 人物タグの作成・編集・削除 | 実装済み |

根拠: `config/routes.rb:23-42`

### 3.3 管理者機能

| route 群 | 主な画面・処理 | 状態 |
|---|---|---|
| `/admin` | 管理 dashboard | 実装済み |
| `/admin/signup` | 管理者新規登録 | 実装済み。固定 Basic 認証 |
| `/admin/users` | 全ユーザー一覧・詳細、ユーザー別データ参照、ユーザー削除 | 実装済み |
| `/admin/meal_plans` | 全献立一覧 | 一覧は実装済み、DELETE は **stub** |
| `/admin/cooking_records` | 全過去料理一覧 | 一覧は実装済み、DELETE は **stub** |
| `/admin/shopping_items` | 全買い物項目一覧 | 一覧は実装済み、DELETE は **stub** |
| `/admin/person_tags` | 全人物タグ一覧 | 一覧は実装済み、DELETE は **stub** |

根拠: `config/routes.rb:44-62`; `app/controllers/admin/meal_plans_controller.rb:5-16`; `app/controllers/admin/cooking_records_controller.rb:5-16`; `app/controllers/admin/shopping_items_controller.rb:5-16`; `app/controllers/admin/person_tags_controller.rb:5-16`

### 3.4 運用・エラー

| route | 用途 | 状態 |
|---|---|---|
| `/up` | Rails 標準 health check | 実装済み |
| `/ping` | 定期アクセス用の文字列応答 | 実装済み |
| `/403`, `/404`, `/500` | エラー表示 | 実装済み |

根拠: `config/routes.rb:2,64-70`

## 4. 主要ユースケース

### 4.1 ユーザー登録とログイン

1. 未ログイン利用者が email、任意の nickname、password を登録する。
2. `User` 保存成功時に `session[:user_id]` が設定され、ホームへ移動する。
3. 通常ログインでは正規化した email で検索し、`authenticate` に成功すると session を設定する。
4. logout は `reset_session` を実行する。

根拠: `app/controllers/users_controller.rb:8-16`; `app/controllers/sessions_controller.rb:7-22`; `app/models/user.rb:18-35`

### 4.2 献立作成から買い物リスト同期

1. 今日以降の日付、昼食/夕食、1件以上の料理を入力する。
2. 料理ごとに食材を登録し、「買い物へ追加」が有効な食材だけ `ShoppingItem` を作る。
3. 人物タグはログインユーザー所有の ID だけに絞る。
4. 献立、タグ、料理、食材、買い物項目は1 transaction で保存する。

過去日付、料理0件、同一ユーザー・日付・食事区分の重複は拒否される。

根拠: `app/controllers/meal_plans_controller.rb:16-45,142-148,236-266`; `app/models/meal_plan.rb:10-16`

テスト期待: `test/integration/meal_plans_test.rb:84-147,347-415`

### 4.3 通常献立編集と quick edit の違い

この2経路は同じ update action に入るが、処理内容が異なる。変更時に統合された処理だと仮定してはならない。

| 項目 | 通常編集 | quick edit |
|---|---|---|
| 分岐 | `quick_update` parameter なし | `quick_update` parameter あり |
| 日付・食事区分 | 更新対象 | 更新しない |
| 料理 | 既存 `plan_dishes` を全削除後に再作成 | ID で既存料理の name/memo を更新 |
| 食材 | 全削除・再作成に伴う | ID 単位で更新・削除、新規追加 |
| 買い物項目 | 食材再作成に伴い再作成 | 対象食材に紐づく項目だけ同期 |
| 応答 | HTML redirect | HTML または Turbo Stream |

根拠:

- 分岐: `app/controllers/meal_plans_controller.rb:53-80`
- 通常編集の全置換: `app/controllers/meal_plans_controller.rb:236-265`
- quick edit: `app/controllers/meal_plans_controller.rb:100-122,150-210`

テスト期待: 通常編集 `test/integration/meal_plans_test.rb:196-237`; quick edit `test/integration/meal_plans_test.rb:239-303`

### 4.4 過去献立の履歴化

ホーム、献立一覧、過去料理一覧への GET 時に、ログインユーザーの「未移行かつ今日より前」の献立を処理する。

1. 献立内の各料理について、元料理 ID が未登録なら `CookingRecord` を作る。
2. 献立の人物タグを履歴へ引き継ぐ。
3. 献立を `migrated=true`、`migrated_at=現在時刻` にする。
4. 献立単位の transaction で行う。

元料理 ID の存在確認と unique 制約により再実行時の重複を避ける設計である。ただし GET が DB 書き込みを行う点は運用上の注意事項である。

根拠: `app/controllers/application_controller.rb:30-56`; 呼び出し元 `app/controllers/home_controller.rb:2-3`, `app/controllers/meal_plans_controller.rb:2-3`, `app/controllers/cooking_records_controller.rb:2-3`

テスト期待: `test/integration/cooking_record_migration_test.rb:18-56`

### 4.5 手動外食と過去料理検索

- `CookingRecordsController#create` は入力に関係なく `eating_out: true` を付け、手動外食として保存する。
- 一覧は既定で履歴を表示せず、全件、直近2週間の昼食/夕食、keyword、人物タグで絞る。
- 複数人物タグはすべてを含む AND 条件である。
- 「外食」に相当する keyword では `eating_out=true` も検索対象になる。

根拠: `app/controllers/cooking_records_controller.rb:17-34,58-121`

テスト期待: `test/integration/cooking_record_migration_test.rb:58-235`

### 4.6 買い物リスト

- 献立由来項目と手動項目を同じ一覧に表示する。
- 手動追加は `manual=true` かつ食材参照なし、献立由来は `manual=false` かつ食材参照必須である。
- 購入状態の変更時に `purchased_at` を自動同期する。
- reorder はログインユーザーの未購入項目だけを更新する。
- 個別操作と購入済み一括削除はログインユーザー scope に限定される。

根拠: `app/controllers/shopping_items_controller.rb:5-130`; `app/models/shopping_item.rb:1-44`

テスト期待: `test/integration/shopping_items_test.rb:18-172`

### 4.7 人物タグ

- ユーザーごとに名前が一意で、前後空白を除去する。
- `default_selected=true` のタグは新規献立画面で初期選択される。
- 献立と過去料理へ多対多で付与でき、別ユーザーのタグ付与は model validation で拒否する。

根拠: `app/models/person_tag.rb:1-16`; `app/models/meal_plan_person_tag.rb:1-16`; `app/models/cooking_record_person_tag.rb:1-16`; `app/views/meal_plans/new.html.erb:114-120`

## 5. 明示的な stub と実機能なし

| 対象 | 現在の動作 | 根拠 |
|---|---|---|
| `MealPlansController#move_dish` | 並び替えず編集画面へ redirect | `app/controllers/meal_plans_controller.rb:87-89` |
| `Admin::MealPlansController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/meal_plans_controller.rb:9-11` |
| `Admin::CookingRecordsController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/cooking_records_controller.rb:9-11` |
| `Admin::ShoppingItemsController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/shopping_items_controller.rb:9-11` |
| `Admin::PersonTagsController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/person_tags_controller.rb:9-11` |
| Job / Mailer / Cable | 基底クラスのみで業務処理なし | [01-system-overview.md](01-system-overview.md#対象外または実機能なし) |

## 6. テスト期待と未確認

テストコードには Integration 57件、Model 10件、Helper 1件の計68件の期待がある。主な対象は認証、献立、買い物、履歴化、人物タグ、管理画面、パスキー options である。

ただし、調査時は MySQL に接続できず suite を実行できていない。そのため本書の「テスト期待あり」はテスト成功を意味しない。実測状況は [04-development-testing-operations.md](04-development-testing-operations.md) を参照する。

未確認事項:

- 実ブラウザー・実端末での WebAuthn 登録とログイン
- production PostgreSQL 上の全ユースケース
- stub route の将来仕様
- 管理者登録を誰がどの運用で実施するか
