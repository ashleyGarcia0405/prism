require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:queries) }
    it { should have_many(:runs) }
  end

  describe 'validations' do
    subject { User.new(name: "Test User", email: "test@example.com", password: "password123", organization: Organization.create!(name: "Test Org")) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should have_secure_password }

    it 'validates email format' do
      user = User.new(name: "Test", email: "invalid", password: "password123", organization: Organization.create!(name: "Org"))
      expect(user.valid?).to be false
      expect(user.errors[:email]).to include("is invalid")
    end

    it 'accepts valid email' do
      org = Organization.create!(name: "Test Org")
      user = User.new(name: "Test", email: "valid@example.com", password: "password123", organization: org)
      expect(user.valid?).to be true
    end
  end

  describe 'password encryption' do
    it 'encrypts password on save' do
      org = Organization.create!(name: "Test Org")
      user = User.create!(name: "Test", email: "test@example.com", password: "password123", organization: org)
      expect(user.password_digest).not_to eq("password123")
    end

    it 'authenticates with correct password' do
      org = Organization.create!(name: "Test Org")
      user = User.create!(name: "Test", email: "test@example.com", password: "password123", organization: org)
      expect(user.authenticate("password123")).to eq(user)
    end

    it 'does not authenticate with wrong password' do
      org = Organization.create!(name: "Test Org")
      user = User.create!(name: "Test", email: "test@example.com", password: "password123", organization: org)
      expect(user.authenticate("wrongpassword")).to be false
    end
  end
end
