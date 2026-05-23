module ApplicationHelper
  def bottom_nav_link(label, path, icon, active:)
    link_to path, class: ("active" if active), aria: { current: ("page" if active) } do
      safe_join([
        bottom_nav_icon(icon),
        tag.span(label, class: "bottom-nav-label")
      ])
    end
  end

  def bottom_nav_icon(icon)
    paths = {
      home: <<~SVG,
        <path d="M4.5 10.2 12 4l7.5 6.2"/>
        <path d="M6.5 9.5v9h4.1v-5h2.8v5h4.1v-9"/>
        <path d="M9.2 18.5h5.6"/>
      SVG
      calendar: <<~SVG,
        <rect x="4.5" y="5.8" width="15" height="13.2" rx="2.4"/>
        <path d="M8 4v4"/>
        <path d="M16 4v4"/>
        <path d="M4.5 10h15"/>
        <path d="M8.1 13.3h.1"/>
        <path d="M12 13.3h.1"/>
        <path d="M15.9 13.3h.1"/>
        <path d="M8.1 16.3h.1"/>
        <path d="M12 16.3h.1"/>
      SVG
      plus: <<~SVG,
        <circle cx="12" cy="12" r="7.5"/>
        <path d="M12 8.4v7.2"/>
        <path d="M8.4 12h7.2"/>
      SVG
      basket: <<~SVG,
        <path d="M6.2 10.2h11.6l-1.1 8.1a2 2 0 0 1-2 1.7H9.3a2 2 0 0 1-2-1.7l-1.1-8.1Z"/>
        <path d="M9.2 10.2 12 5.2l2.8 5"/>
        <path d="M9.4 13.2v3.6"/>
        <path d="M12 13.2v3.6"/>
        <path d="M14.6 13.2v3.6"/>
      SVG
      diary: <<~SVG,
        <path d="M7 5.2h8.8A2.2 2.2 0 0 1 18 7.4v11.4H8.2A2.2 2.2 0 0 1 6 16.6V6.2a1 1 0 0 1 1-1Z"/>
        <path d="M9 5.2v13.6"/>
        <path d="M11.2 9h4"/>
        <path d="M11.2 12h3.2"/>
        <path d="M6 16.6a2.2 2.2 0 0 1 2.2-2.2H18"/>
      SVG
      tag: <<~SVG
        <path d="M5.5 6.3v5.4l7.2 7.2a1.8 1.8 0 0 0 2.5 0l3.7-3.7a1.8 1.8 0 0 0 0-2.5L11.7 5.5H6.3a.8.8 0 0 0-.8.8Z"/>
        <circle cx="9" cy="9" r="1.1"/>
      SVG
    }

    tag.span(class: "bottom-nav-icon", aria: { hidden: true }) do
      raw <<~SVG
        <svg viewBox="0 0 24 24" focusable="false">
          #{paths.fetch(icon)}
        </svg>
      SVG
    end
  end

  def app_date(date, with_year: false)
    return "" if date.blank?

    with_year ? date.strftime("%Y/%m/%d") : date.strftime("%m/%d")
  end

  def shopping_item_context(item)
    meal_plan = item.meal_plan
    plan_dish = item.plan_dish

    return "手動追加" if meal_plan.blank? || plan_dish.blank?

    "#{app_date(meal_plan.meal_date)}/#{shopping_meal_type_label(meal_plan.meal_type)} #{plan_dish.name}"
  end

  def shopping_meal_type_label(meal_type)
    { "lunch" => "昼", "dinner" => "夕" }.fetch(meal_type.to_s, meal_type.to_s)
  end
end
