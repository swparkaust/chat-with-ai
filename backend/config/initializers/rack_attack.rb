# frozen_string_literal: true

class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    namespace: 'rack_attack'
  )

  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1' if Rails.env.development?
  end

  # --- Throttles

  throttle('messages/device', limit: 30, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/conversations/') && req.path.end_with?('/messages') && req.post?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  throttle('profiles/device', limit: 10, period: 1.minute) do |req|
    if req.path == '/api/v1/profiles/me' && req.put?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  # Higher than messages/device: typing indicators legitimately fire rapidly
  throttle('user_state/device', limit: 60, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/conversations/') && req.path.end_with?('/user_state') && req.put?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  throttle('auth/ip', limit: 20, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/auth/') && req.post?
      req.ip
    end
  end

  throttle('uploads/device', limit: 10, period: 1.minute) do |req|
    if req.path == '/api/v1/direct_uploads' && req.post?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  # Generous ceilings: normal clients poll read receipts and typing state
  throttle('api/ip', limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  throttle('api/device', limit: 200, period: 1.minute) do |req|
    req.env['HTTP_X_DEVICE_ID'] if req.path.start_with?('/api/')
  end

  # --- Blocklists

  blocklist('block-bad-requests') do |req|
    # Missing or scripted User-Agent = likely a bot
    req.user_agent.blank? ||
    req.user_agent =~ /curl|wget|python|scrapy/i
  end

  # --- Responses

  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'Content-Type' => 'application/json',
      'Retry-After' => match_data[:period].to_s,
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s
    }

    body = {
      error: '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.',
      retry_after: match_data[:period]
    }.to_json

    [429, headers, [body]]
  end

  self.blocklisted_responder = lambda do |env|
    [403, { 'Content-Type' => 'application/json' }, [{ error: '접근이 거부되었습니다.' }.to_json]]
  end

  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    Rails.logger.warn "[Rack::Attack] Throttled #{req.env['rack.attack.match_type']}: " \
                      "#{req.ip} #{req.request_method} #{req.fullpath} " \
                      "(device_id: #{req.env['HTTP_X_DEVICE_ID']})"
  end

  # Log blocked requests
  ActiveSupport::Notifications.subscribe('blocklist.rack_attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    Rails.logger.warn "[Rack::Attack] Blocked: #{req.ip} #{req.request_method} #{req.fullpath}"
  end
end
