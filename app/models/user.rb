class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  # Notes must be declared before folders: dependent callbacks run in declaration order, and
  # notes.folder_id references folders. delete_all skips Folder's restrict_with_error guards,
  # which exist to protect interactive deletes, not account deletion.
  has_many :notes, dependent: :delete_all
  has_many :folders, dependent: :delete_all
  has_many :access_grants, class_name: "Doorkeeper::AccessGrant", foreign_key: :resource_owner_id, dependent: :delete_all
  has_many :access_tokens, class_name: "Doorkeeper::AccessToken", foreign_key: :resource_owner_id, dependent: :delete_all

  after_create :create_root_folder

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :username, with: ->(u) { u.strip.downcase.presence }
  validates :username, uniqueness: true, allow_nil: true, length: { in: 3..30 },
    format: { with: /\A[a-z0-9_-]+\z/, message: "may only contain lowercase letters, numbers, hyphens and underscores" }

  def root_folder
    folders.find_by!(parent_id: nil, name: "/")
  end

  private
    def create_root_folder
      folders.create!(name: "/")
    end
end
