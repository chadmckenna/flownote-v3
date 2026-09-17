require "test_helper"

class Notes::LinkResolverTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def resolve(*targets, user: @user)
    Notes::LinkResolver.new(user: user).resolve(targets)
  end

  test "resolves an exact title" do
    assert_equal notes(:one), resolve("First note")["First note"]
  end

  test "matches regardless of ASCII case and surrounding whitespace" do
    assert_equal notes(:one), resolve("first NOTE")["first NOTE"]
    assert_equal notes(:one), resolve("  First note  ")["First note"]
  end

  test "an unknown title resolves to nothing" do
    assert_nil resolve("No such note")["No such note"]
  end

  test "another user's note never resolves" do
    assert_nil resolve(notes(:two).title)[notes(:two).title]
  end

  test "a duplicated title resolves to the most recently updated note" do
    older = @user.notes.create!(title: "Duplicated", body: "older", folder: folders(:work))
    newer = @user.notes.create!(title: "Duplicated", body: "newer", folder: folders(:projects))

    assert_equal newer, resolve("Duplicated")["Duplicated"]

    older.touch
    assert_equal older, resolve("Duplicated")["Duplicated"]
  end

  test "a folder-qualified target picks the note in that folder" do
    @user.notes.create!(title: "Duplicated", body: "in work", folder: folders(:work))
    in_projects = @user.notes.create!(title: "Duplicated", body: "in projects", folder: folders(:projects))

    assert_equal in_projects, resolve("Work/Projects/Duplicated")["Work/Projects/Duplicated"]
  end

  test "a folder path is case-insensitive and tolerates a leading ~/ or /" do
    note = @user.notes.create!(title: "Qualified", body: "x", folder: folders(:work))

    assert_equal note, resolve("work/Qualified")["work/Qualified"]
    assert_equal note, resolve("~/Work/Qualified")["~/Work/Qualified"]
    assert_equal note, resolve("/Work/Qualified")["/Work/Qualified"]
  end

  test "~/ alone qualifies the root folder" do
    assert_equal notes(:root_note), resolve("~/Root note")["~/Root note"]
    assert_nil resolve("~/First note")["~/First note"]
  end

  test "a wrong folder path resolves to nothing" do
    assert_nil resolve("Projects/First note")["Projects/First note"]
  end

  test "blank targets are ignored" do
    assert_empty resolve("", "   ")
  end

  test "resolves many targets in a single query" do
    titles = [ "First note", "Root note", "Shared note", "Nope" ]

    assert_queries_count 1 do
      Notes::LinkResolver.new(user: @user).resolve(titles)
    end
  end

  test "loads folders only when a target is folder-qualified" do
    assert_queries_count 2 do
      Notes::LinkResolver.new(user: @user).resolve([ "First note", "Work/First note" ])
    end
  end

  test "caps the number of targets it will look up" do
    targets = Array.new(Notes::LinkResolver::MAX_TARGETS + 50) { |i| "Title #{i}" }

    assert_equal Notes::LinkResolver::MAX_TARGETS, resolve(*targets).size
  end
end
