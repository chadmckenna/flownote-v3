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

  test "limits the number of results" do
    folder = folders(:work)
    (Notes::Search::LIMIT + 5).times do |i|
      @user.notes.create!(title: "Searchable note #{i}", body: "x", folder: folder)
    end

    assert_equal Notes::Search::LIMIT, search("Searchable note").size
  end
end
