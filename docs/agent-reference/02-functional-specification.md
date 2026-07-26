# 機能仕様

## 1. 記載区分

- **実装済み**: controller、model、view、route から処理を確認できる。
- **テスト期待**: Minitestに期待が記載されている範囲。
- **テスト実測あり**: 2026-07-26 に Minitest と Chrome system test の成功を確認した範囲。
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
| `/meal_plans` | 今日以降の献立一覧、作成、献立全体の通常編集、削除。一覧の各料理から通常編集へ直接遷移する | 実装済み。server-sideの`quick_update`分岐は維持されるが、一覧にquick edit UIはない |
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

根拠: `MealPlansController#create`, `#past_meal_date?`, `#selected_person_tag_ids`, `#save_meal_plan!`（`app/controllers/meal_plans_controller.rb`）; `app/models/meal_plan.rb:10-16`

テスト期待: `test/integration/meal_plans_test.rb`の「user creates a meal plan with multiple dishes ingredients person tags and shopping items」「user cannot create meal plan without required fields or dishes」「duplicate meal plan does not leave partial related data」

### 4.3 通常献立編集と quick edit の違い

この2経路は同じ update action に入るが、処理内容が異なる。変更時に統合された処理だと仮定してはならない。Issue #7で廃止したのは献立一覧のquick edit UIであり、server-sideの`quick_update` parameter分岐と更新処理ではない。

| 項目 | 通常編集 | server-side quick update |
|---|---|---|
| 分岐 | `quick_update` parameter なし | `quick_update` parameter あり |
| 対象 | ログインユーザー所有かつ未移行の献立 | ログインユーザー所有かつ未移行の献立 |
| 日付・食事区分 | 更新対象 | 更新しない |
| 料理 | hidden ID で既存料理を差分更新し、新規追加・任意削除も行う | ID で既存料理の name/memo を更新 |
| 食材 | hidden ID で差分更新・追加・削除 | ID 単位で更新・削除、新規追加 |
| 買い物項目 | 食材の名称と追加指定の状態遷移に応じて差分同期 | 対象食材に紐づく項目だけ同期 |
| 応答 | HTML redirect | HTML または Turbo Stream |

通常編集では、フォームに `PlanDish.id` と `DishIngredient.id` をhidden fieldとして保持する。更新開始前にStrong Parameters、料理・食材collectionの形、ID重複、nested IDの所有範囲を検証し、1 transaction内で対象献立をlockして差分同期する。

期待するparameter shapeは次のとおり。料理と食材のcollection keyは数字文字列である。既存レコードは`id`を含み、新規レコードは`id`を省略する。

```text
meal_date
meal_type
person_tag_ids[]
dishes["0"] {
  id, name, memo,
  ingredients["0"] { id, name, add_to_shopping_list }
}
```

- GET/PATCHの対象献立が他ユーザー所有または移行済みの場合は404とする。
- 別献立・別料理・他ユーザー所有・存在しないnested IDは404とし、変更を残さない。
- collectionの不正な形、料理・食材IDの重複、料理0件、日付・食事区分・料理名の空欄、過去日付、日付・食事区分の重複は422とし、関連変更をすべてrollbackする。
- 日付は今日または未来へ変更できる。
- 既存料理は名称・メモを変更でき、新規料理は存続する料理の最大`position`より後へ連番で追加する。送信から除いた料理は削除する。
- 未変更の`PlanDish`、`DishIngredient`、`ShoppingItem`、人物タグjoinは保存処理を行わず、ID、`updated_at`、`position`、`eating_out`、`memo`、`purchased`、`purchased_at`、`sort_order`、`manual`等を保持する。
- 食材が未変更なら買い物項目にも書き込まない。買い物追加が有効なまま食材名だけ変わった場合は買い物項目の名称だけを変え、購入情報等は保持する。
- 買い物追加が無効から有効になった場合は既存項目を再利用し、なければ作成する。有効から無効、食材削除、料理削除の場合は、購入済みを含む紐づく買い物項目を削除する。
- 削除予定の料理を参照する`CookingRecord`がある場合は、mutation前に422として更新全体を拒否する。`CookingRecord`自体は通常編集で変更しない。

通常編集への画面導線と操作仕様:

- 献立一覧では、登録済みの各料理カード全体が所属献立の`/meal_plans/:id/edit`を`href`に持つanchorである。同じ献立に複数料理がある場合は、すべて同じ編集URLを使用する。
- 料理anchorは`data-turbo-frame="_top"`を持ち、一覧を囲む`turbo-frame#meal_plans`の外へtop-level navigationする。quick edit drawerや「献立全体を編集」という中間リンクは表示しない。
- 通常のanchorであるためJavaScript無効時も遷移でき、TabでfocusしてEnterで開ける。JavaScript無効化、Tab/Enter、320px幅での横overflowなしと遷移はSystem testで実測済みである。
- 献立未登録の昼食・夕食枠は「未登録」というテキストのままで、anchorにしない。
- 通常編集では全料理に削除ボタンを表示し、最後の1件も画面上では削除できる。料理0件のまま送信すると422になる。
- 削除確認をキャンセルした場合はDOMとhidden IDを保持する。削除確定後は次の料理、前の料理、「料理を追加」ボタンの順でfocusを移す。
- 料理削除はEnter/Spaceでも操作できる。日付inputの最小値は当日である。
- 320px幅では、献立一覧と通常編集画面の双方について横overflowなしと主要操作をSystem testで確認した。

一覧UIとserver-side処理の境界:

- `app/views/meal_plans/_list.html.erb`からquick edit用フォーム、template、drawer、backdrop、`meal-plan-edit` Stimulus属性を削除した。
- `app/javascript/controllers/meal_plan_edit_controller.js`を削除し、献立一覧で不要になった`MealPlansController#prepare_index_state`内の人物タグ一覧queryを削除した。
- quick edit drawer専用のCSS selector群は削除した。一方、買い物リストと過去料理で使用する共通drawerのview、Stimulus controller、CSSは維持した。
- `MealPlansController#update`の`quick_update`分岐、`#quick_update`、食材・買い物項目の同期処理、およびIntegration testは維持した。
- route、DB schema、migration、外部サービスへの変更はない。

根拠:

- 対象scope・分岐: `MealPlansController#set_editable_meal_plan`, `#update`, `#quick_update`
- 入力検証: `MealPlansController#full_update_params`, `#validated_update_collection`, `#validate_full_update_input!`, `#validate_full_update_ids!`
- 差分同期: `MealPlansController#sync_full_update!`, `#sync_dishes_for_full_update!`, `#sync_ingredients_for_full_update!`, `#sync_existing_full_ingredient!`
- 履歴保護: `MealPlansController#reject_cooking_record_dish_deletion!`
- hidden ID・日付・削除操作: `app/views/meal_plans/edit.html.erb`; `MealPlanFormController#removeDish`
- 一覧からの直接導線: `app/views/meal_plans/_list.html.erb:1,24-48`
- 一覧用query: `MealPlansController#prepare_index_state`（`app/controllers/meal_plans_controller.rb:90-94`）
- 一覧カードCSSと共通drawer CSS: `app/assets/stylesheets/application.css:637-660,1093-1174`

テスト根拠: `test/integration/meal_plans_test.rb:54-74,192-211,954-1018`および同ファイルの通常編集、scope、不正shape、不正nested ID、重複ID、rollback、買い物同期、CookingRecord保護、作成・削除の各ケース; `test/system/meal_plan_edit_test.rb:21-123`の直接遷移、Tab/Enter、JavaScript無効、一覧と通常編集の320px、削除確認・focus・keyboardの各ケース

### 4.4 過去献立の履歴化

ホーム、献立一覧、過去料理一覧への GET 時に、ログインユーザーの「未移行かつ今日より前」の献立を処理する。

1. 献立内の各料理について、元料理 ID が未登録なら `CookingRecord` を作る。
2. 献立の人物タグを履歴へ引き継ぐ。
3. 献立を `migrated=true`、`migrated_at=現在時刻` にする。
4. 献立単位の transaction で行う。

元料理 ID の存在確認と unique 制約により再実行時の重複を避ける設計である。ただし GET が DB 書き込みを行う点は運用上の注意事項である。

根拠: `ApplicationController#migrate_past_meal_plans!`; 呼び出し元は`HomeController`, `MealPlansController`, `CookingRecordsController`のbefore_action宣言

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
| `MealPlansController#move_dish` | 並び替えず編集画面へ redirect | `MealPlansController#move_dish`（`app/controllers/meal_plans_controller.rb`） |
| `Admin::MealPlansController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/meal_plans_controller.rb:9-11` |
| `Admin::CookingRecordsController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/cooking_records_controller.rb:9-11` |
| `Admin::ShoppingItemsController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/shopping_items_controller.rb:9-11` |
| `Admin::PersonTagsController#destroy` | 削除せず一覧へ redirect | `app/controllers/admin/person_tags_controller.rb:9-11` |
| Job / Mailer / Cable | 基底クラスのみで業務処理なし | [01-system-overview.md](01-system-overview.md#対象外または実機能なし) |

## 6. テスト実測と未確認

2026-07-26の実測結果は次のとおり。

| 対象 | seed | 結果 |
|---|---:|---|
| `test/integration/meal_plans_test.rb` | 29490 | 33 runs、300 assertions、0 failures、0 errors、0 skips |
| `test/system/meal_plan_edit_test.rb` | 56906 | 7 runs、34 assertions、0 failures、0 errors、0 skips |
| `test/integration/shopping_items_test.rb` | 28223 | 10 runs、299 assertions、0 failures、0 errors、0 skips |
| `test/system/shopping_items_test.rb` | 27001 | 4 runs、140 assertions、0 failures、0 errors、0 skips |
| `test/integration/cooking_record_migration_test.rb` | 7999 | 9 runs、63 assertions、0 failures、0 errors、0 skips |
| Rails test全体 | 42423 | 88 runs、860 assertions、0 failures、0 errors、0 skips |
| System test全体 | 1887 | 11 runs、174 assertions、0 failures、0 errors、0 skips |
| 0件シナリオの一時テスト | 11629 | 1 run、3 assertions、0 failures、0 errors、0 skips |
| 過去料理drawerの一時System test | 2757 | 1 run、4 assertions、0 failures、0 errors、0 skips |

記録された同一seedでの再実行も成功した。最初のIntegration test実行はsandboxからMySQL socketへ接続できず失敗したが、test DBに限定した許可済み環境で再実行して成功したため、製品不具合とは判定されていない。test DBの作成・migration・dropは実行していない。詳細は [04-development-testing-operations.md](04-development-testing-operations.md) を参照する。

未確認事項:

- 実ブラウザー・実端末での WebAuthn 登録とログイン
- production PostgreSQL 上の全ユースケース
- 通常編集とquick editを同じ献立へ同時実行した場合の競合結果
- production/stagingでのIssue #7の導線
- production相当データ量での通常編集性能と、320pxを含む実端末固有の表示・操作差
- 過去料理drawer保存を実ブラウザーで最初から最後まで行う一連の操作
- stub route の将来仕様
- 管理者登録を誰がどの運用で実施するか
