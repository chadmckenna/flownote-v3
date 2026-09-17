module ApplicationHelper
  MARKDOWN_OPTIONS = {
    extension: { table: true, strikethrough: true, autolink: true, tagfilter: true, tasklist: true },
    render: { unsafe: false, hardbreaks: true, github_pre_lang: false }
  }.freeze

  # [[Note title]] — the target may be folder-qualified ([[Work/Title]]) or name
  # a folder outright ([[Work/]]). Brackets
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
  # separate method rather than a flag on render_markdown, so a caller has to ask
  # for note knowledge before it can leak any.
  #
  # Links resolve at render time, so moving a note leaves every link to it
  # working; renaming one breaks them, and they fall back to the missing-link
  # styling rather than disappearing.
  #
  # from: the note being rendered, which link targets are resolved relative to.
  def render_linked_markdown(text, user:, from: nil)
    return render_markdown(text) if user.nil?

    link_targets(text, Notes::LinkResolver.new(user: user, from: from))
  end

  # Same, but every [[wiki link]] renders unresolved. A share page is read by
  # someone with no account behind it, and must never disclose another note's
  # title, id, or folder no matter who happens to be signed in while viewing — so
  # nothing is looked up at all, and the target stays the author's own text,
  # styled as a link that leads nowhere.
  def render_public_markdown(text)
    link_targets(text, nil)
  end

  private
    # Runs over the rendered HTML rather than the markdown source: Commonmarker
    # has already isolated code in <pre>/<code>, so skipping those (plus existing
    # links) keeps [[...]] inside a code block from becoming a link. Working on
    # the source with a gsub would rewrite code blocks and, because a title is
    # arbitrary user text, could inject a link of the title's choosing.
    def link_targets(text, resolver)
      html = render_markdown(text)
      return html if text.to_s.exclude?("[[")

      fragment = Nokogiri::HTML5.fragment(html)
      nodes = fragment.xpath(".//text()").select { |node| linkable?(node) }
      return html if nodes.empty?

      targets = nodes.flat_map { |node| node.text.scan(NOTE_LINK).flatten }
      resolved = resolver ? resolver.resolve(targets) : {}

      nodes.each { |node| node.replace(note_links_html(node.text, resolved)) }
      fragment.to_html.html_safe
    end

    def linkable?(node)
      node.text.include?("[[") && node.ancestors.none? { |a| %w[a code pre].include?(a.name) }
    end

    # Rebuilds one text node as HTML: escape everything that isn't a link, and
    # emit markup only for the [[...]] runs.
    def note_links_html(text, targets)
      text.split(/(\[\[#{NOTE_LINK_TARGET}\]\])/o).reject(&:empty?).map do |segment|
        target = segment[NOTE_LINK, 1]&.strip

        if target.nil?
          ERB::Util.html_escape(segment)
        elsif (record = targets[target])
          note_link_tag(record)
        else
          tag.span(target, class: "note-link--missing")
        end
      end.join
    end

    # A folder link lands on the folder's own page — the same view the sidebar
    # navigates to — and wears a trailing slash so it reads as a directory
    # rather than as another note.
    def note_link_tag(record)
      unless record.is_a?(Folder)
        return tag.a(record.title, href: folder_note_path(record.folder_id, record), data: { note_link: true })
      end

      root = record.root?
      tag.a(root ? "~/" : "#{record.name}/", href: root ? root_path : folder_path(record), data: { note_link: true })
    end
end
