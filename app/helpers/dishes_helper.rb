module DishesHelper
  DISH_ICON_RULES = [
    { icon: "🍛", keywords: %w[カレー カツカレー キーマカレー ドライカレー ハヤシライス ビーフシチュー] },
    { icon: "🍣", keywords: %w[寿司 すし 鮨 海鮮丼 手巻き寿司 ちらし寿司] },
    { icon: "🍜", keywords: %w[ラーメン らーめん 拉麺 うどん そば 蕎麦 焼きそば 冷やし中華 そうめん にゅうめん] },
    { icon: "🍝", keywords: %w[パスタ スパゲティ スパゲッティ ナポリタン カルボナーラ ペペロンチーノ ミートソース] },
    { icon: "🍕", keywords: %w[ピザ マルゲリータ] },
    { icon: "🍔", keywords: %w[ハンバーガー バーガー] },
    { icon: "🌮", keywords: %w[タコス ブリトー ケバブ] },
    { icon: "🥟", keywords: %w[餃子 シュウマイ 焼売 小籠包 春巻き] },
    { icon: "🍙", keywords: %w[おにぎり おむすび] },
    { icon: "🍞", keywords: %w[パン トースト サンドイッチ ホットサンド フレンチトースト] },
    { icon: "🍚", keywords: %w[ご飯 ごはん 白米 米 飯 炊き込みご飯 混ぜご飯 チャーハン 炒飯 ピラフ オムライス リゾット 雑炊 お茶漬け] },
    { icon: "🍱", keywords: %w[弁当 お弁当 定食 幕の内] },
    { icon: "🍤", keywords: %w[天丼 天ぷら 海老天 エビ天 かき揚げ] },
    { icon: "🍖", keywords: %w[牛丼 豚丼 親子丼 カツ丼 そぼろ丼 ステーキ 焼肉 生姜焼き 唐揚げ からあげ とんかつ カツ ハンバーグ チキン 豚肉 牛肉 鶏肉 肉じゃが] },
    { icon: "🐟", keywords: %w[魚 鮭 サケ さけ サバ 鯖 アジ 鯵 ブリ 鰤 まぐろ マグロ カツオ 鰹 さんま 秋刀魚 いわし 鰯 ししゃも 焼き魚 煮魚 刺身] },
    { icon: "🦐", keywords: %w[海老 エビ えび shrimp シーフード イカ いか タコ たこ あさり しじみ ホタテ 牡蠣 カキ] },
    { icon: "🥗", keywords: %w[サラダ 野菜 和え物 ナムル おひたし マリネ コールスロー] },
    { icon: "🥔", keywords: %w[じゃがいも ジャガイモ ポテト コロッケ ポテトサラダ 肉じゃが] },
    { icon: "🍅", keywords: %w[トマト ミネストローネ トマト煮] },
    { icon: "🍆", keywords: %w[なす ナス 茄子 麻婆茄子] },
    { icon: "🥦", keywords: %w[ブロッコリー アスパラ ほうれん草 小松菜] },
    { icon: "🥕", keywords: %w[にんじん 人参 キャロット] },
    { icon: "🥣", keywords: %w[味噌汁 みそ汁 スープ 豚汁 けんちん汁 お吸い物 コンソメ ポタージュ シチュー クラムチャウダー] },
    { icon: "🍲", keywords: %w[鍋 おでん すき焼き しゃぶしゃぶ キムチ鍋 水炊き 湯豆腐] },
    { icon: "🥚", keywords: %w[卵 玉子 たまご 目玉焼き 卵焼き 玉子焼き オムレツ スクランブルエッグ] },
    { icon: "⬜", keywords: %w[豆腐 冷奴 湯豆腐 厚揚げ 油揚げ 納豆] },
    { icon: "🥢", keywords: %w[中華 麻婆 麻婆豆腐 回鍋肉 ホイコーロー 青椒肉絲 チンジャオロース 八宝菜 酢豚 エビチリ 中華丼 ビビンバ クッパ チヂミ プルコギ] },
    { icon: "🥪", keywords: %w[サンド サンドイッチ ホットサンド] },
    { icon: "🥞", keywords: %w[パンケーキ ホットケーキ ワッフル] },
    { icon: "🥐", keywords: %w[クロワッサン ベーグル デニッシュ] },
    { icon: "🍰", keywords: %w[ケーキ チーズケーキ ショートケーキ タルト プリン ゼリー パフェ アイス アイスクリーム] },
    { icon: "🍎", keywords: %w[りんご リンゴ バナナ みかん オレンジ いちご イチゴ ぶどう キウイ フルーツ 果物] },
    { icon: "☕", keywords: %w[コーヒー 珈琲 カフェラテ 紅茶 お茶] },
    { icon: "🥛", keywords: %w[牛乳 ミルク ヨーグルト] }
  ].freeze

  def dish_icon(name)
    normalized_name = name.to_s.downcase

    rule = DISH_ICON_RULES.find do |candidate|
      candidate[:keywords].any? { |keyword| normalized_name.include?(keyword.downcase) }
    end

    rule ? rule[:icon] : "🍽️"
  end
end
