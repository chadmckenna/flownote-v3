module ApplicationHelper
  def render_markdown(text)
    return "".html_safe if text.blank?

    Commonmarker.to_html(
      text,
      options: {
        extension: { table: true, strikethrough: true, autolink: true, tagfilter: true },
        render: { unsafe: false, hardbreaks: false }
      }
    ).html_safe
  end
end
