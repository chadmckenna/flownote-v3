require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # A view has every helper mixed in; ActionView::TestCase only mixes in the one
  # under test, and note_link_tag builds a folder href with FoldersHelper.
  include FoldersHelper

  setup do
    @user = users(:one)
    @note = notes(:one)
    @path = folder_note_path(@note.folder_id, @note)
  end

  test "renders a wiki link to the note" do
    html = render_linked_markdown("See [[First note]] for details.", user: @user)

    assert_includes html, %(<a href="#{@path}" data-note-link="true">First note</a>)
  end

  test "renders a wiki link to a folder" do
    html = render_linked_markdown("See [[Work/]] for details.", user: @user)

    assert_includes html, %(<a href="#{folder_path(folders(:work))}" data-note-link="true">Work/</a>)
  end

  test "renders a wiki link to the root folder" do
    html = render_linked_markdown("Back to [[~/]].", user: @user)

    assert_includes html, %(<a href="/" data-note-link="true">~/</a>)
  end

  test "the nearer folder wins over an exact .md spelling further away" do
    near_dir = @user.folders.create!(name: "sub", parent: folders(:work))
    far_dir = @user.folders.create!(name: "sub", parent: folders(:root_one))
    near = @user.notes.create!(title: "Notes", body: "x", folder: near_dir)
    @user.notes.create!(title: "Notes.md", body: "x", folder: far_dir)

    html = render_linked_markdown("[[sub/Notes.md]]", user: @user, from: @note)

    assert_includes html, %(href="#{folder_note_path(near.folder_id, near)}")
  end

  test "renders an unresolved folder link as marked plain text" do
    html = render_linked_markdown("See [[No such folder/]].", user: @user)

    assert_includes html, %(<span class="note-link--missing">No such folder/</span>)
    assert_no_match(/<a /, html)
  end

  test "renders an unresolved link as marked plain text" do
    html = render_linked_markdown("See [[No such note]].", user: @user)

    assert_includes html, %(<span class="note-link--missing">No such note</span>)
    assert_no_match(/<a /, html)
  end

  test "render_public_markdown marks every link unresolved without looking any up" do
    assert_queries_count 0 do
      html = render_public_markdown("See [[First note]] and [[Work/]].")

      assert_includes html, %(<span class="note-link--missing">First note</span>)
      assert_includes html, %(<span class="note-link--missing">Work/</span>)
      assert_no_match(/<a /, html)
    end
  end

  test "render_public_markdown leaves a link inside code alone" do
    html = render_public_markdown("Type `[[First note]]` to link.")

    assert_includes html, "<code>[[First note]]</code>"
    assert_no_match(/note-link--missing/, html)
  end

  test "render_public_markdown escapes the target text" do
    html = render_public_markdown(%([[Tom & "Jerry"]]))

    assert_includes html, %(<span class="note-link--missing">Tom &amp; "Jerry"</span>)
  end

  # Same as for a signed-in reader: the renderer strips raw HTML before the link
  # pass sees it, so such a target simply isn't marked up at all.
  test "render_public_markdown never renders raw HTML in a target" do
    html = render_public_markdown("[[Danger <script>]]")

    assert_no_match(/<script>/, html)
    assert_no_match(/<a /, html)
  end

  test "links nothing without a user" do
    assert_equal render_markdown("See [[First note]]."), render_linked_markdown("See [[First note]].", user: nil)
  end

  test "leaves a wiki link inside inline code alone" do
    html = render_linked_markdown("Type `[[First note]]` to link.", user: @user)

    assert_includes html, "<code>[[First note]]</code>"
    assert_no_match(/<a /, html)
  end

  test "leaves a wiki link inside a fenced code block alone" do
    html = render_linked_markdown("```\n[[First note]]\n```", user: @user)

    assert_includes html, "[[First note]]"
    assert_no_match(/<a /, html)
  end

  test "leaves a wiki link inside an existing link's text alone" do
    html = render_linked_markdown("[a [[First note]] b](/somewhere)", user: @user)

    assert_includes html, %(<a href="/somewhere">a [[First note]] b</a>)
    assert_no_match(/#{@path}/, html)
  end

  test "escapes the text around a link" do
    html = render_linked_markdown("1 < 2 & [[First note]]", user: @user)

    assert_includes html, "1 &lt; 2 &amp; "
    assert_includes html, %(<a href="#{@path}")
  end

  test "escapes a title containing markup characters" do
    hostile = @user.notes.create!(title: %(Tom & "Jerry"), body: "x", folder: folders(:work))
    html = render_linked_markdown(%([[Tom & "Jerry"]]), user: @user)

    assert_includes html, %(<a href="#{folder_note_path(hostile.folder_id, hostile)}")
    assert_includes html, %(Tom &amp; "Jerry")
  end

  # A note link's href is always built from the target's own folder and id, so a
  # title can never supply one — the source text of the link is never re-parsed
  # as markdown, only the already-rendered text is rewritten.
  test "a title cannot smuggle in an href of its own" do
    @user.notes.create!(title: "X](https://evil.example) [y", body: "x", folder: folders(:work))
    html = render_linked_markdown("[[X](https://evil.example) [y]] and [[First note]]", user: @user)

    hrefs = Nokogiri::HTML5.fragment(html).css("a[data-note-link]").map { |a| a["href"] }
    assert_equal [ @path ], hrefs
  end

  # The target is held back from the renderer, so a title made of raw HTML is
  # linkable like any other — and goes out escaped, as its own link text.
  test "a title containing raw HTML never renders that HTML" do
    note = @user.notes.create!(title: "Danger <script>", body: "x", folder: folders(:work))
    html = render_linked_markdown("[[Danger <script>]]", user: @user)

    assert_no_match(/<script>/, html)
    assert_includes html, %(<a href="#{folder_note_path(note.folder_id, note)}" data-note-link="true">Danger &lt;script&gt;</a>)
  end

  # Markdown punctuation inside a target used to be rendered as markdown and take
  # the link apart — two absolute links on a line read as a strikethrough between
  # them, since GFM accepts a single tilde.
  test "two absolute links on one line each render as a link" do
    root = notes(:root_note)
    html = render_linked_markdown("See [[~/Root note]] and [[~/Work/First note]].", user: @user)

    assert_includes html, %(<a href="#{folder_note_path(root.folder_id, root)}" data-note-link="true">Root note</a>)
    assert_includes html, %(<a href="#{@path}" data-note-link="true">First note</a>)
    assert_no_match(%r{<del>}, html)
  end

  test "a target holding markdown punctuation still resolves" do
    %w[ *starred* _snaked_ `ticked` ~tilded~ ].each do |title|
      note = @user.notes.create!(title: title, body: "x", folder: folders(:work))
      html = render_linked_markdown("[[#{title}]]", user: @user)

      assert_includes html, %(href="#{folder_note_path(note.folder_id, note)}"), "#{title} did not link"
      assert_no_match(%r{<em>|<code>|<del>}, html)
    end
  end

  test "resolves several links in one document" do
    html = render_linked_markdown("[[First note]] and [[Root note]] and [[First note]]", user: @user)

    assert_equal 3, html.scan(/<a /).size
    assert_includes html, folder_note_path(notes(:root_note).folder_id, notes(:root_note))
  end

  test "another user's note never links" do
    html = render_linked_markdown("[[#{notes(:two).title}]]", user: @user)

    assert_includes html, %(<span class="note-link--missing">)
    assert_no_match(/<a /, html)
  end

  test "leaves the rest of the markdown intact" do
    html = render_linked_markdown("# Heading\n\n| a | b |\n| - | - |\n| 1 | 2 |\n\n[[First note]]", user: @user)

    assert_includes html, ">Heading</h1>"
    assert_includes html, "<table>"
    assert_includes html, %(<a href="#{@path}")
  end

  test "render_markdown leaves wiki links as literal text" do
    html = render_markdown("See [[First note]].")

    assert_includes html, "[[First note]]"
    assert_no_match(/<a /, html)
  end
end
