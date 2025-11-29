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
end

puts "Creating Season 1..."

# Create the first season (inactive first to bypass name validation)
season = Season.create!(
  season_number: 1,
  start_date: Time.current,
  active: false
)

puts "Generating AI persona..."

persona_prompt = "25세 서울 사는 직장인 여자, 밝고 친근하며 감성적인 성격"
provider = Ai::ProviderFactory.default
generator = Ai::PersonaGenerator.new(provider)
result = generator.generate(persona_prompt)
persona_data = result[:state_data]
memories_data = result[:memories]

first_name = result[:first_name]
last_name = result[:last_name]
status_message = result[:status_message]
full_name = "#{last_name}#{first_name}"

puts "AI Persona generated: #{full_name} (#{persona_data['name_chinese']})"
puts "Age: #{persona_data['age']}, Occupation: #{persona_data['occupation']}"

season.update!(
  first_name: first_name,
  last_name: last_name,
  status_message: status_message,
  active: true
)

# Update the PersonaState (already created by after_create callback) with generated data
persona_state = season.persona_state
persona_state.update!(state_data: persona_data)

puts "PersonaState updated with #{persona_data.keys.count} attributes"

puts "Initializing persona tools..."
tool_manager = Persona::Tools::ToolManager.new(season)
provider = Ai::ProviderFactory.default
system_context = Ai::SystemContextBuilder.new(persona_state, nil).build

# Execute tool chain with empty conversation to initialize based on persona context
results = tool_manager.execute_tool_chain(provider, system_context, "")
puts "Initialized tools with #{results.count} initial actions"

if memories_data.present?
  puts "Creating #{memories_data.count} initial memories..."

  memories_data.each do |memory_data|
    PersonaMemory.create!(
      season: season,
      content: memory_data['content'] || memory_data[:content],
      significance: memory_data['significance'] || memory_data[:significance] || 5.0,
      emotional_intensity: memory_data['emotional_intensity'] || memory_data[:emotional_intensity] || 5.0,
      detail_level: memory_data['detail_level'] || memory_data[:detail_level] || 1.0,
      tags: memory_data['tags'] || memory_data[:tags] || [],
      memory_timestamp: Time.current,
      recall_count: 0
    )
  end

  puts "Created #{season.persona_memories.count} memories"
end

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
puts "AI Persona: #{full_name} (#{persona_data['name_chinese']})"
puts "Age: #{persona_data['age']}, Sex: #{persona_data['sex']}"
puts "Occupation: #{persona_data['occupation']}"
puts "Initial memories: #{season.persona_memories.count}"
if Rails.env.development?
  puts "Test user device_id: #{User.last.device_id}"
end
puts "="*50
