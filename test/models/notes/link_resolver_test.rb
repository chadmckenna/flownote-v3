require "test_helper"

class Notes::LinkResolverTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def resolve(*targets, user: @user, from: nil)
    Notes::LinkResolver.new(user: user, from: from).resolve(targets)
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

  test "an unqualified target prefers a note in the linking note's own folder" do
    here = @user.notes.create!(title: "Duplicated", body: "in work", folder: folders(:work))
    @user.notes.create!(title: "Duplicated", body: "in root", folder: folders(:root_one))

    assert_equal here, resolve("Duplicated", from: notes(:one))["Duplicated"]
  end

  test "an unqualified target still finds a note in another folder" do
    assert_equal notes(:root_note), resolve("Root note", from: notes(:one))["Root note"]
  end

  test "a relative path descends from the linking note's folder" do
    note = @user.notes.create!(title: "Deep", body: "x", folder: folders(:projects))

    assert_equal note, resolve("Projects/Deep", from: notes(:one))["Projects/Deep"]
  end

  test "a relative path climbs with .. and ignores ." do
    from = @user.notes.create!(title: "Deep", body: "x", folder: folders(:projects))

    assert_equal notes(:one), resolve("../First note", from: from)["../First note"]
    assert_equal notes(:root_note), resolve("../../Root note", from: from)["../../Root note"]
    assert_equal notes(:one), resolve("./../First note", from: from)["./../First note"]
  end

  test "climbing past the root resolves to nothing" do
    assert_nil resolve("../First note", from: notes(:root_note))["../First note"]
  end

  test "an absolute path ignores the linking note's folder" do
    from = @user.notes.create!(title: "Deep", body: "x", folder: folders(:projects))

    assert_equal notes(:root_note), resolve("/Root note", from: from)["/Root note"]
    assert_equal notes(:root_note), resolve("~/Root note", from: from)["~/Root note"]
    assert_equal notes(:one), resolve("/Work/First note", from: from)["/Work/First note"]
    assert_nil resolve("/First note", from: from)["/First note"]
  end

  test "a relative path falls back to the same path read from the root" do
    target = "Work/Projects/Shared note"

    assert_equal notes(:published), resolve(target, from: notes(:one))[target]
  end

  test "a trailing .md is optional" do
    assert_equal notes(:one), resolve("First note.md")["First note.md"]
    assert_equal notes(:one), resolve("Work/First note.md")["Work/First note.md"]
  end

  test "a title that really ends in .md wins over the stripped one" do
    @user.notes.create!(title: "Readme", body: "x", folder: folders(:work))
    dotted = @user.notes.create!(title: "Readme.md", body: "x", folder: folders(:work))

    assert_equal dotted, resolve("Readme.md")["Readme.md"]
  end

  test "a target with a trailing slash resolves to a folder" do
    assert_equal folders(:work), resolve("Work/")["Work/"]
    assert_equal folders(:projects), resolve("Work/Projects/")["Work/Projects/"]
  end

  test "a trailing slash resolves relative to the linking note's folder" do
    assert_equal folders(:projects), resolve("Projects/", from: notes(:one))["Projects/"]
    assert_equal folders(:work), resolve("../", from: notes(:published))["../"]
  end

  test "a lone ~/ or / resolves to the root folder" do
    assert_equal folders(:root_one), resolve("~/")["~/"]
    assert_equal folders(:root_one), resolve("/")["/"]
    assert_equal folders(:root_one), resolve("~")["~"]
  end

  test "a target naming no note falls back to a folder of that path" do
    assert_equal folders(:work), resolve("Work")["Work"]
    assert_equal folders(:projects), resolve("Work/Projects")["Work/Projects"]
    assert_equal folders(:projects), resolve("Projects", from: notes(:one))["Projects"]
  end

  test "a note wins over a folder of the same name" do
    note = @user.notes.create!(title: "Work", body: "x", folder: folders(:root_one))

    assert_equal note, resolve("Work")["Work"]
    # ...but the trailing slash asks for the folder outright.
    assert_equal folders(:work), resolve("Work/")["Work/"]
  end

  test "a nearby folder wins over a note in some unrelated folder" do
    @user.notes.create!(title: "Projects", body: "x", folder: folders(:root_one))

    assert_equal folders(:projects), resolve("Projects", from: notes(:one))["Projects"]
  end

  test "another user's folder never resolves" do
    assert_nil resolve("Personal/")["Personal/"]
  end

  test "an unknown folder resolves to nothing" do
    assert_nil resolve("No such folder/")["No such folder/"]
    assert_nil resolve("../../../", from: notes(:one))["../../../"]
  end

  # The folded namespace the resolver assumes is now enforced by the database, so
  # a target can no longer match two notes or two folders that differ in case.
  test "case folding cannot make a target ambiguous" do
    assert_raises ActiveRecord::RecordNotUnique do
      @user.notes.build(title: notes(:one).title.swapcase, body: "x", folder: folders(:work)).save!(validate: false)
    end

    assert_raises ActiveRecord::RecordNotUnique do
      @user.folders.build(name: folders(:work).name.swapcase, parent: folders(:root_one)).save!(validate: false)
    end
  end

  test "blank targets are ignored" do
    assert_empty resolve("", "   ")
  end

  # One query for the notes and one for the folders, however many targets there
  # are — a page full of links must not turn into a page full of queries.
  test "resolves many targets in a fixed number of queries" do
    targets = [ "First note", "Work/Projects/Shared note", "Root note", "Work/", "~/", "Nope" ]
    targets += Array.new(60) { |i| "Title #{i}" }
    from = notes(:one)

    assert_queries_count 2 do
      Notes::LinkResolver.new(user: @user, from: from).resolve(targets)
    end
  end

  test "skips the note query when every target names a folder" do
    assert_queries_count 1 do
      Notes::LinkResolver.new(user: @user).resolve([ "Work/", "~/" ])
    end
  end

  test "caps the number of targets it will look up" do
    targets = Array.new(Notes::LinkResolver::MAX_TARGETS + 50) { |i| "Title #{i}" }

    assert_equal Notes::LinkResolver::MAX_TARGETS, resolve(*targets).size
  end
end
