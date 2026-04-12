class Note < ApplicationRecord
  belongs_to :user
  belongs_to :folder
  has_rich_text :body

  validates :title, presence: true
end
