module ApplicationHelper
  def render_markdown(text)
    return "".html_safe if text.blank?

    Commonmarker.to_html(
      text,
      options: {
        extension: { table: true, strikethrough: true, autolink: true, tagfilter: true, tasklist: true },
        render: { unsafe: false, hardbreaks: true, github_pre_lang: false }
      },
      # hardbreaks: true renders every newline as a <br>. Notes are written in
      # a plain text editor where a line break is meant literally, so markdown's
      # soft-break-joins-lines rule reads as a bug here.
      #
      # Disable Commonmarker's built-in highlighter (inline-style spans with a
      # baked theme). Code blocks are highlighted client-side by highlight.js so
      # they follow the user's light/dark theme. github_pre_lang: false emits
      # <pre><code class="language-x"> for highlight.js to read.
      plugins: { syntax_highlighter: nil }
    ).html_safe
  end
end
