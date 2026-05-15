class Note < ApplicationRecord
  belongs_to :user
  belongs_to :folder, touch: true

  validates :title, presence: true

  broadcasts_refreshes
end
