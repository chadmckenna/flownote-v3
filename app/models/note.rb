class Note < ApplicationRecord
  # Short, opaque, URL-safe. A note is public exactly when it has a slug, so
  # unpublishing revokes the old link for good and republishing mints a new one.
  SLUG_CHARS = [ *"a".."z", *"0".."9" ].freeze
  SLUG_LENGTH = 8

  belongs_to :user
  belongs_to :folder, touch: true

  # Titles are file names: unique within their folder, as on a filesystem. The
  # database index is the real guarantee — two simultaneous saves get past the
  # validation — and it's what lets a link like [[test/CLAUDE]] name one note.
  validates :title, presence: true, uniqueness: { scope: :folder_id, message: "already exists in this folder" }
  validates :slug, uniqueness: true, allow_nil: true, format: { with: /\A[a-z0-9]+\z/ }
  # folder_id is mass-assignable, so without this a crafted request could file a
  # note into someone else's folder. Mirrors Folder#parent_belongs_to_same_user.
  validate :folder_belongs_to_same_user

  scope :published, -> { where.not(slug: nil) }

  broadcasts_refreshes

  def self.generate_slug
    loop do
      candidate = SecureRandom.alphanumeric(SLUG_LENGTH, chars: SLUG_CHARS)
      break candidate unless exists?(slug: candidate)
    end
  end

  def published? = slug.present?

  # A published note is only reachable while its owner has a username — the
  # public URL embeds one.
  def shareable? = published? && user.username.present?
  def publish! = update!(slug: self.class.generate_slug)
  def unpublish! = update!(slug: nil)

  private
    def folder_belongs_to_same_user
      if folder && folder.user_id != user_id
        errors.add(:folder, "must belong to the same user")
      end
    end
end
