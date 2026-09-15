require "test_helper"

class Notes::SearchTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def search(query, user: @user)
    Notes::Search.new(user: user, query: query).results
  end

  test "matches on title" do
    assert_includes search("First note"), notes(:one)
  end

  test "matches on body" do
    assert_includes search("Body of the first"), notes(:one)
  end

  test "is case-insensitive" do
    assert_includes search("first note"), notes(:one)
  end

  test "blank query returns nothing" do
    assert_empty search("")
    assert_empty search("   ")
    assert_empty search(nil)
  end

  test "only returns the given user's notes" do
    results = search("note", user: @user)
    assert_includes results, notes(:one)
    assert_not_includes results, notes(:two)
  end

  test "treats LIKE wildcards as literal characters" do
    assert_empty search("%")
  end

  test "matches an underscored title whether searched with spaces or underscores" do
    note = @user.notes.create!(title: "sourdough_bread", body: "x", folder: folders(:work))

    assert_includes search("sourdough_bread"), note
    assert_includes search("sourdough bread"), note
  end

  test "requires every token to be present" do
    note = @user.notes.create!(title: "sourdough_bread", body: "x", folder: folders(:work))

    assert_not_includes search("sourdough rye"), note
  end

  test "matches on the folder path" do
    assert_includes search("Work"), notes(:one)
    assert_includes search("Projects"), notes(:published)
  end

  test "a folder token matches notes in its subfolders too" do
    # :published lives in Work/Projects.
    assert_includes search("Work"), notes(:published)
  end

  test "combines a folder token with a title token" do
    filed = @user.notes.create!(title: "sourdough", body: "x", folder: folders(:projects))
    elsewhere = @user.notes.create!(title: "sourdough", body: "x", folder: folders(:root_one))

    results = search("projects sourdough")

    assert_includes results, filed
    assert_not_includes results, elsewhere
  end

  test "a note that contains the token outranks a folderful that doesn't" do
    crowd = folders(:projects)
    (Notes::Search::LIMIT + 2).times { |i| @user.notes.create!(title: "dinner #{i}", body: "x", folder: crowd) }
    titled = @user.notes.create!(title: "Projects shopping list", body: "eggs", folder: folders(:root_one))
    crowd.notes.each(&:touch)

    results = search("Projects")

    assert_includes results, titled
    assert_equal Notes::Search::LIMIT, results.size
  end

  test "folder matches still fill the slots a content match leaves" do
    filed = @user.notes.create!(title: "no keyword here", body: "x", folder: folders(:projects))

    assert_includes search("Projects"), filed
  end

  test "a folder path never matches another user's notes" do
    assert_not_includes search("Personal"), notes(:two)
  end

  test "limits the number of results" do
    folder = folders(:work)
    (Notes::Search::LIMIT + 5).times do |i|
      @user.notes.create!(title: "Searchable note #{i}", body: "x", folder: folder)
    end

    assert_equal Notes::Search::LIMIT, search("Searchable note").size
  end
end
