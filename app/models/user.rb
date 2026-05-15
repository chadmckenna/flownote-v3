class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :notes, dependent: :destroy

  after_create :create_root_folder

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def root_folder
    folders.find_by!(parent_id: nil, name: "/")
  end

  private
    def create_root_folder
      folders.create!(name: "/")
    end
end
