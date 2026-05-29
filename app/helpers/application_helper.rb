module ApplicationHelper
  def render_markdown(text)
    return "".html_safe if text.blank?

    Commonmarker.to_html(
      text,
      options: {
        extension: { table: true, strikethrough: true, autolink: true, tagfilter: true },
        render: { unsafe: false, hardbreaks: false, github_pre_lang: false }
      },
      # Disable Commonmarker's built-in highlighter (inline-style spans with a
      # baked theme). Code blocks are highlighted client-side by highlight.js so
      # they follow the user's light/dark theme. github_pre_lang: false emits
      # <pre><code class="language-x"> for highlight.js to read.
      plugins: { syntax_highlighter: nil }
    ).html_safe
  end
end
