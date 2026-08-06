class Note < ApplicationRecord
  # Short, opaque, URL-safe. A note is public exactly when it has a slug, so
  # unpublishing revokes the old link for good and republishing mints a new one.
  SLUG_CHARS = [ *"a".."z", *"0".."9" ].freeze
  SLUG_LENGTH = 8

  belongs_to :user
  belongs_to :folder, touch: true

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_nil: true, format: { with: /\A[a-z0-9]+\z/ }

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
end
