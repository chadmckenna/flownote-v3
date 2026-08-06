require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ApiTestHelper

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "downcases and strips username, blanks become nil" do
    assert_equal "handle", User.new(username: " Handle ").username
    assert_nil User.new(username: "  ").username
  end

  test "username cannot change while notes are published" do
    user = users(:one)
    assert_predicate user.notes.published, :any?, "precondition: fixture note is published"

    assert_not user.update(username: "renamed")
    assert_includes user.errors[:username], "can't be changed while you have published notes — unpublish them first"
    assert_not user.reload.update(username: nil)
  end

  test "username can change once nothing is published" do
    user = users(:one)
    user.notes.published.find_each(&:unpublish!)

    assert user.update(username: "renamed")
  end

  test "username can be set for the first time even with published notes" do
    user = users(:one)
    user.update_column(:username, nil)

    assert user.update(username: "freshname")
  end

  test "destroy removes everything owned by the user" do
    user = users(:one)
    session = user.sessions.create!
    token = create_access_token(user: user)

    assert_predicate user.folders, :any?
    assert_predicate user.notes, :any?

    user.destroy!

    assert_empty Folder.where(user_id: user.id)
    assert_empty Note.where(user_id: user.id)
    assert_not Session.exists?(session.id)
    assert_not Doorkeeper::AccessToken.exists?(token.id)
  end
end
