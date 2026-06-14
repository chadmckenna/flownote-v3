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

  test "renders an empty frame for a blank query" do
    get search_path, params: { q: "" }
    assert_response :success
    assert_select "turbo-frame#search_results"
    assert_select ".file-listing", count: 0
  end
end
