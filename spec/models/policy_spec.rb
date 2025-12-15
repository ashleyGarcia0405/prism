require 'rails_helper'

RSpec.describe Policy, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
  end

  describe 'validations' do
    let(:organization) { Organization.create!(name: 'Test Org') }

    it 'creates a valid policy' do
      policy = organization.policies.build(name: 'Test Policy', rules: 'rule content')
      expect(policy).to be_valid
    end
  end
end
