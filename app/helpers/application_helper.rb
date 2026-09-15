module ApplicationHelper
  MARKDOWN_OPTIONS = {
    extension: { table: true, strikethrough: true, autolink: true, tagfilter: true, tasklist: true },
    render: { unsafe: false, hardbreaks: true, github_pre_lang: false }
  }.freeze

  # [[Note title]] — the target may be folder-qualified ([[Work/Title]]). Brackets
  # and newlines are excluded from the target, so a title can never break out of
  # the markup and a link never spans a line.
  NOTE_LINK_TARGET = /[^\[\]\n]+/
  NOTE_LINK = /\[\[(#{NOTE_LINK_TARGET})\]\]/

  def render_markdown(text)
    return "".html_safe if text.blank?

    Commonmarker.to_html(
      text,
      options: MARKDOWN_OPTIONS,
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

  # Same, but with [[wiki links]] resolved against `user`'s notes. Deliberately a
  # separate method rather than a flag on render_markdown: public share pages call
  # render_markdown, which has no note knowledge and so cannot disclose another
  # note's title, id, or folder no matter who is signed in while viewing.
  #
  # Links resolve at render time, so moving a note leaves every link to it
  # working; renaming one breaks them, and they fall back to the missing-link
  # styling rather than disappearing.
  def render_linked_markdown(text, user:)
    html = render_markdown(text)
    return html if user.nil? || text.to_s.exclude?("[[")

    link_notes(html, user: user)
  end

  private
    # Runs over the rendered HTML rather than the markdown source: Commonmarker
    # has already isolated code in <pre>/<code>, so skipping those (plus existing
    # links) keeps [[...]] inside a code block from becoming a link. Working on
    # the source with a gsub would rewrite code blocks and, because a title is
    # arbitrary user text, could inject a link of the title's choosing.
    def link_notes(html, user:)
      fragment = Nokogiri::HTML5.fragment(html)
      nodes = fragment.xpath(".//text()").select { |node| linkable?(node) }
      return html if nodes.empty?

      targets = nodes.flat_map { |node| node.text.scan(NOTE_LINK).flatten }
      notes = Notes::LinkResolver.new(user: user).resolve(targets)

      nodes.each { |node| node.replace(note_links_html(node.text, notes)) }
      fragment.to_html.html_safe
    end

    def linkable?(node)
      node.text.include?("[[") && node.ancestors.none? { |a| %w[a code pre].include?(a.name) }
    end

    # Rebuilds one text node as HTML: escape everything that isn't a link, and
    # emit markup only for the [[...]] runs.
    def note_links_html(text, notes)
      text.split(/(\[\[#{NOTE_LINK_TARGET}\]\])/o).reject(&:empty?).map do |segment|
        target = segment[NOTE_LINK, 1]&.strip

        if target.nil?
          ERB::Util.html_escape(segment)
        elsif (note = notes[target])
          tag.a(note.title, href: folder_note_path(note.folder_id, note), data: { note_link: true })
        else
          tag.span(target, class: "note-link--missing")
        end
      end.join
    end
end
