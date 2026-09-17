module ApplicationHelper
  MARKDOWN_OPTIONS = {
    extension: { table: true, strikethrough: true, autolink: true, tagfilter: true, tasklist: true },
    render: { unsafe: false, hardbreaks: true, github_pre_lang: false }
  }.freeze

  # [[Note title]] — the target may be folder-qualified ([[Work/Title]]) or name
  # a folder outright ([[Work/]]). Brackets and newlines are excluded from the
  # target, so a title can never break out of the markup and a link never spans
  # a line.
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
    # Every [[...]] run is swapped for an opaque token before the markdown is
    # rendered, and the tokens are swapped back afterwards. Markdown punctuation
    # inside a target would otherwise be rendered as markdown and take the link
    # apart: two [[~/a]] links on a line read as a ~strikethrough~ between them,
    # and a title holding * or _ or ` fared no better.
    #
    # The swap back happens on the rendered tree, not the source, so Commonmarker
    # has already isolated code in <pre>/<code>: a token there (or inside a link)
    # becomes the literal text the author typed, exactly as before. Everything
    # emitted is escaped or built with tag helpers, so an arbitrary title still
    # can't inject markup or an href of its own.
    def link_targets(text, resolver)
      return render_markdown(text) if text.to_s.exclude?("[[")

      targets = []
      # Unguessable, so a target cannot contain a token and impersonate another,
      # and free of markdown punctuation, so the renderer leaves it alone.
      nonce = SecureRandom.hex(8)
      masked = text.gsub(NOTE_LINK) do
        targets << Regexp.last_match(1)
        "#{nonce}#{targets.size - 1}#{nonce}"
      end

      fragment = Nokogiri::HTML5.fragment(render_markdown(masked))
      nodes = fragment.xpath(".//text()").select { |node| node.text.include?(nonce) }
      return render_markdown(text) if nodes.empty?

      resolved = resolver ? resolver.resolve(targets.map(&:strip)) : {}

      nodes.each { |node| node.replace(note_links_html(node, nonce, targets, resolved)) }
      fragment.to_html.html_safe
    end

    # Rebuilds one text node as HTML: escape everything that isn't a token, and
    # emit markup only for the tokens — unless the node sits somewhere a link has
    # no business being, where the author's own text goes back verbatim.
    def note_links_html(node, nonce, targets, resolved)
      linkable = node.ancestors.none? { |ancestor| %w[a code pre].include?(ancestor.name) }
      delimiter = Regexp.escape(nonce)

      node.text.split(/(#{delimiter}\d+#{delimiter})/).reject(&:empty?).map do |segment|
        next ERB::Util.html_escape(segment) unless segment.start_with?(nonce)

        target = targets[segment.delete_prefix(nonce).delete_suffix(nonce).to_i]
        next ERB::Util.html_escape("[[#{target}]]") unless linkable

        if (record = resolved[target.strip])
          note_link_tag(record)
        else
          tag.span(target.strip, class: "note-link--missing")
        end
      end.join
    end

    # A folder link lands on the folder's own page — the same view the sidebar
    # navigates to — and wears a trailing slash so it reads as a directory
    # rather than as another note.
    def note_link_tag(record)
      if record.is_a?(Folder)
        tag.a(record.root? ? "~/" : "#{record.name}/", href: folder_or_root_path(record), data: { note_link: true })
      else
        tag.a(record.title, href: folder_note_path(record.folder_id, record), data: { note_link: true })
      end
    end
end
