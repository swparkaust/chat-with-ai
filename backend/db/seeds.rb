if Rails.env.development?
  puts "Cleaning existing data..."
  Message.destroy_all
  Conversation.destroy_all
  UserState.destroy_all
  PersonaMemory.destroy_all
  PersonaState.destroy_all
  PushSubscription.destroy_all
  User.destroy_all
  Season.destroy_all
elsif Season.current.present?
  # Guard on an ACTIVE season, not mere existence: a prior seed that died
  # during persona generation must not block the rerun
  puts "An active season already exists, skipping seed."
  exit
end

puts "Creating the first season..."

# Clear residue from any previously crashed seed/rotation attempt so
# season numbering starts at 1
SeasonServices::RotationManagerService.destroy_unnamed_husks

# Create the first season (inactive first to bypass name validation)
season = Season.create!(
  start_date: Time.current,
  active: false
)

puts "Generating AI persona..."

persona_prompt = "25세 서울 사는 직장인 여자, 밝고 친근하며 감성적인 성격"

begin
  SeasonServices::RotationManagerService.initialize_persona(season, prompt: persona_prompt)
  season.update!(active: true)
rescue StandardError
  # Leave nothing behind so the seed is rerunnable after a transient AI
  # failure; a cleanup failure must not mask the original error
  begin
    season.destroy!
  rescue StandardError => cleanup_error
    puts "WARNING: failed to clean up season row: #{cleanup_error.message}"
  end
  raise
end

persona_data = season.persona_state.state_data

puts "AI Persona generated: #{season.full_name} (#{persona_data['name_chinese']})"
puts "Age: #{season.persona_state.age}, Occupation: #{persona_data['occupation']}"
puts "PersonaState updated with #{persona_data.keys.count} attributes"
puts "Created #{season.persona_memories.count} memories"

if Rails.env.development?
  puts "Creating sample test user..."

  test_user = User.create!(
    device_id: "test-device-#{SecureRandom.hex(8)}",
    name: "테스트 사용자",
    status_message: "개발 테스트 중",
    last_seen_at: Time.current
  )

  puts "Test user created: #{test_user.device_id}"

  conversation = Conversation.create!(
    user: test_user,
    season: season
  )

  # UserState is automatically created by the conversation's after_create callback

  puts "Test conversation created"
end

puts "\n" + "="*50
puts "Seed completed successfully!"
puts "="*50
puts "Season ##{season.season_number} created"
puts "AI Persona: #{season.full_name} (#{persona_data['name_chinese']})"
puts "Age: #{season.persona_state.age}, Sex: #{persona_data['sex']}"
puts "Occupation: #{persona_data['occupation']}"
puts "Initial memories: #{season.persona_memories.count}"
if Rails.env.development?
  puts "Test user device_id: #{User.last.device_id}"
end
puts "="*50
