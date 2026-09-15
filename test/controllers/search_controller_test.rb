require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "requires authentication" do
    sign_out
    get search_path, params: { q: "note" }
    assert_redirected_to new_session_path
  end

  test "returns matching notes in the results frame" do
    get search_path, params: { q: "First note" }
    assert_response :success
    assert_select "turbo-frame#search_results"
    assert_select ".file-listing__name", text: "First note"
  end

  test "shows the folder path of each result" do
    get search_path, params: { q: "First note" }

    assert_select ".file-listing__meta", text: "~/Work"
  end

  test "finds notes by their folder path" do
    get search_path, params: { q: "Work" }

    assert_select ".file-listing__name", text: "First note"
  end

  test "does not return another user's notes" do
    get search_path, params: { q: "Second note" }
    assert_response :success
    assert_select ".file-listing__name", text: "Second note", count: 0
  end

  test "shows an empty state when nothing matches" do
    get search_path, params: { q: "nothing-here-matches" }
    assert_response :success
    assert_select ".search-modal__empty"
  end

  test "renders an empty frame for a blank query with nothing visited yet" do
    get search_path, params: { q: "" }
    assert_response :success
    assert_select "turbo-frame#search_results"
    assert_select ".file-listing", count: 0
  end

  test "a blank query offers the notes visited most recently, newest first" do
    [ notes(:one), notes(:root_note), notes(:published) ].each do |note|
      get folder_note_path(note.folder, note)
    end

    get search_path, params: { q: "" }

    assert_select ".search-modal__label", "Recent"
    assert_select ".file-listing__name" do |names|
      assert_equal [ "Shared note", "Root note", "First note" ], names.map(&:text)
    end
  end

  test "revisiting a note moves it back to the top without duplicating it" do
    get folder_note_path(notes(:one).folder, notes(:one))
    get folder_note_path(notes(:root_note).folder, notes(:root_note))
    get folder_note_path(notes(:one).folder, notes(:one))

    get search_path, params: { q: "" }

    assert_select ".file-listing__name" do |names|
      assert_equal [ "First note", "Root note" ], names.map(&:text)
    end
  end

  test "keeps only the most recent five" do
    notes = (1..7).map { |i| @user.notes.create!(title: "Visited #{i}", body: "x", folder: folders(:work)) }
    notes.each { |note| get folder_note_path(note.folder, note) }

    get search_path, params: { q: "" }

    assert_select ".file-listing li", RecentNotes::LIMIT
    assert_select ".file-listing__name", text: "Visited 7"
    assert_select ".file-listing__name", text: "Visited 2", count: 0
  end

  test "a typed query replaces the recent list with results" do
    get folder_note_path(notes(:root_note).folder, notes(:root_note))

    get search_path, params: { q: "First note" }

    assert_select ".search-modal__label", count: 0
    assert_select ".file-listing__name", text: "First note"
    assert_select ".file-listing__name", text: "Root note", count: 0
  end

  test "signing in as someone else starts the recent list over" do
    get folder_note_path(notes(:one).folder, notes(:one))
    sign_out
    sign_in_as(users(:two))
    get folder_note_path(notes(:two).folder, notes(:two))

    get search_path, params: { q: "" }

    assert_select ".file-listing__name", text: "Second note"
    assert_select ".file-listing__name", text: "First note", count: 0
    assert_equal [ notes(:two).id ], session[:recent_note_ids]
  end

  test "the note being viewed is left out of the recent list" do
    get folder_note_path(notes(:one).folder, notes(:one))
    get folder_note_path(notes(:root_note).folder, notes(:root_note))

    get search_path, params: { q: "", current: notes(:root_note).id }

    assert_select ".file-listing__name", text: "First note"
    assert_select ".file-listing__name", text: "Root note", count: 0
  end

  test "a prefetched page view is not recorded as a visit" do
    get folder_note_path(notes(:one).folder, notes(:one)), headers: { "X-Sec-Purpose" => "prefetch" }

    get search_path, params: { q: "" }

    assert_select ".file-listing", count: 0
  end

  test "an id for a deleted note is dropped from the session, not just the list" do
    note = @user.notes.create!(title: "Temporary", body: "x", folder: folders(:work))
    get folder_note_path(note.folder, note)
    get folder_note_path(notes(:one).folder, notes(:one))
    note.destroy

    get search_path, params: { q: "" }

    assert_select ".file-listing li", 1
    assert_equal [ notes(:one).id ], session[:recent_note_ids]
  end
end
