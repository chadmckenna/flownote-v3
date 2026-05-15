class Folder < ApplicationRecord
  belongs_to :user
  belongs_to :parent, class_name: "Folder", optional: true, touch: true

  has_many :subfolders, class_name: "Folder", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :notes, dependent: :restrict_with_error

  validates :name, presence: true
  validates :name, uniqueness: { scope: [ :user_id, :parent_id ], message: "already exists in this folder" }
  validate :parent_belongs_to_same_user
  validate :not_ancestor_of_self, if: :parent_id_changed?
  validate :root_folder_immutable, on: :update

  broadcasts_refreshes

  def root?
    parent_id.nil? && name == "/"
  end

  def ancestors
    chain = []
    current = self
    while current.parent
      chain.unshift(current.parent)
      current = current.parent
    end
    chain
  end

  before_destroy :prevent_root_destroy

  private
    def root_folder_immutable
      was_root = parent_id_was.nil? && name_was == "/"
      if was_root && (name_changed? || parent_id_changed?)
        errors.add(:base, "Root folder cannot be modified")
      end
    end

    def prevent_root_destroy
      if root?
        errors.add(:base, "Root folder cannot be deleted")
        throw :abort
      end
    end

    def parent_belongs_to_same_user
      if parent && parent.user_id != user_id
        errors.add(:parent, "must belong to the same user")
      end
    end

    def not_ancestor_of_self
      current = parent
      while current
        if current.id == id
          errors.add(:parent, "would create a circular reference")
          return
        end
        current = current.parent
      end
    end
end
