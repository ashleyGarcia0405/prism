class Organization < ApplicationRecord
  has_many :datasets, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :name, presence: true
end
