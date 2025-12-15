# frozen_string_literal: true

# Data Rooms Demo Setup Script
# Run with: rails runner db/seeds_demo.rb

puts "🎬 Setting up Data Rooms Demo Environment..."
puts "=" * 60

# Clean existing demo data (optional - comment out if you want to keep existing data)
# puts "\n🧹 Cleaning existing data..."
# DataRoomInvitation.destroy_all
# DataRoomParticipant.destroy_all
# DataRoom.destroy_all
# Query.destroy_all
# Dataset.destroy_all
# User.destroy_all
# Organization.destroy_all

puts "\n📊 Creating Organizations..."

# Organization 1: Hospital A
hospital_a = Organization.find_or_create_by!(name: "City General Hospital")
puts "✓ Created: #{hospital_a.name}"

# Organization 2: Hospital B
hospital_b = Organization.find_or_create_by!(name: "Memorial Medical Center")
puts "✓ Created: #{hospital_b.name}"

# Organization 3: Hospital C (optional third participant)
hospital_c = Organization.find_or_create_by!(name: "University Health System")
puts "✓ Created: #{hospital_c.name}"

puts "\n👥 Creating Users..."

# Users for Hospital A
alice = User.find_or_create_by!(email: "alice@citygeneral.org") do |user|
  user.name = "Alice Johnson"
  user.organization = hospital_a
  user.password = "password123"
  user.password_confirmation = "password123"
end
puts "✓ Created: #{alice.name} (#{alice.email}) - #{hospital_a.name}"

# Users for Hospital B
bob = User.find_or_create_by!(email: "bob@memorial.org") do |user|
  user.name = "Bob Smith"
  user.organization = hospital_b
  user.password = "password123"
  user.password_confirmation = "password123"
end
puts "✓ Created: #{bob.name} (#{bob.email}) - #{hospital_b.name}"

# Users for Hospital C
charlie = User.find_or_create_by!(email: "charlie@university.org") do |user|
  user.name = "Charlie Davis"
  user.organization = hospital_c
  user.password = "password123"
  user.password_confirmation = "password123"
end
puts "✓ Created: #{charlie.name} (#{charlie.email}) - #{hospital_c.name}"

puts "\n📁 Creating Datasets..."

# Dataset for Hospital A
dataset_a = Dataset.find_or_create_by!(
  name: "City General Patient Records 2024",
  organization: hospital_a
) do |ds|
  ds.description = "Anonymized patient encounter data from City General Hospital"
  ds.table_name = "hospital_a_patients"
  ds.columns = {
    "patient_id" => "integer",
    "age" => "integer",
    "diagnosis_code" => "string",
    "treatment_cost" => "numeric",
    "length_of_stay" => "integer",
    "admission_date" => "date"
  }
  ds.row_count = 15000
end
puts "✓ Created: #{dataset_a.name} (#{dataset_a.row_count} rows)"

# Dataset for Hospital B
dataset_b = Dataset.find_or_create_by!(
  name: "Memorial Patient Database 2024",
  organization: hospital_b
) do |ds|
  ds.description = "De-identified patient records from Memorial Medical Center"
  ds.table_name = "hospital_b_patients"
  ds.columns = {
    "patient_id" => "integer",
    "age" => "integer",
    "diagnosis_code" => "string",
    "treatment_cost" => "numeric",
    "length_of_stay" => "integer",
    "admission_date" => "date"
  }
  ds.row_count = 12000
end
puts "✓ Created: #{dataset_b.name} (#{dataset_b.row_count} rows)"

# Dataset for Hospital C
dataset_c = Dataset.find_or_create_by!(
  name: "University Health Patient Data 2024",
  organization: hospital_c
) do |ds|
  ds.description = "Research-grade patient data from University Health System"
  ds.table_name = "hospital_c_patients"
  ds.columns = {
    "patient_id" => "integer",
    "age" => "integer",
    "diagnosis_code" => "string",
    "treatment_cost" => "numeric",
    "length_of_stay" => "integer",
    "admission_date" => "date"
  }
  ds.row_count = 18000
end
puts "✓ Created: #{dataset_c.name} (#{dataset_c.row_count} rows)"

puts "\n" + "=" * 60
puts "✅ Demo environment setup complete!"
puts "=" * 60

puts "\n📋 Demo Credentials:"
puts "-" * 60
puts "Hospital A (Creator):"
puts "  Email:    alice@citygeneral.org"
puts "  Password: password123"
puts "  Dataset:  #{dataset_a.name}"
puts ""
puts "Hospital B (Participant):"
puts "  Email:    bob@memorial.org"
puts "  Password: password123"
puts "  Dataset:  #{dataset_b.name}"
puts ""
puts "Hospital C (Participant):"
puts "  Email:    charlie@university.org"
puts "  Password: password123"
puts "  Dataset:  #{dataset_c.name}"
puts "-" * 60

puts "\n🎯 Next Steps:"
puts "1. Start the Rails server: bin/rails server"
puts "2. Login as Alice: http://localhost:3000/login"
puts "3. Create a new data room"
puts "4. Invite Hospital B and Hospital C"
puts "5. Check emails in browser (letter_opener)"
puts "6. Login as Bob/Charlie to accept invitations"
puts "7. Attest with datasets"
puts "8. Execute MPC computation"
puts "9. View collaborative results!"
puts ""
puts "🎬 Ready to demo! See DEMO_GUIDE.md for detailed walkthrough."
puts "=" * 60
