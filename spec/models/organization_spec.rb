require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe 'associations' do
    it { should have_many(:users) }
    it { should have_many(:datasets) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end
end
