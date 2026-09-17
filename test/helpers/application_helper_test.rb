require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
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

  # A title with raw HTML in it is stripped by the renderer before the link pass
  # sees it, so such a note simply isn't linkable — and nothing is emitted.
  test "a title containing raw HTML never renders that HTML" do
    @user.notes.create!(title: "Danger <script>", body: "x", folder: folders(:work))
    html = render_linked_markdown("[[Danger <script>]]", user: @user)

    assert_no_match(/<script>/, html)
    assert_no_match(/<a /, html)
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
