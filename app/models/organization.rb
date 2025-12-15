class Organization < ApplicationRecord
  has_many :datasets, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :policies, dependent: :destroy

  validates :name, presence: true
end
