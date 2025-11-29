# frozen_string_literal: true

class Rack::Attack
  # Configure Redis as the cache store for Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    namespace: 'rack_attack'
  )

  # Always allow requests from localhost in development
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1' if Rails.env.development?
  end

  # ========================================
  # Throttles (Rate Limiting)
  # ========================================

  # Throttle message sending per device
  # Limit: 30 messages per minute per device
  throttle('messages/device', limit: 30, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/conversations/') && req.path.end_with?('/messages') && req.post?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  # Throttle profile updates per device
  # Limit: 10 updates per minute per device
  throttle('profiles/device', limit: 10, period: 1.minute) do |req|
    if req.path == '/api/v1/profiles/me' && req.put?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  # Throttle user state updates (typing indicator) per device
  # Limit: 60 updates per minute per device (allow rapid typing indicator updates)
  throttle('user_state/device', limit: 60, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/conversations/') && req.path.end_with?('/user_state') && req.put?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  # Throttle authentication attempts per IP
  # Limit: 20 attempts per minute per IP
  throttle('auth/ip', limit: 20, period: 1.minute) do |req|
    if req.path.start_with?('/api/v1/auth/') && req.post?
      req.ip
    end
  end

  # Throttle file uploads per device
  # Limit: 10 uploads per minute per device
  throttle('uploads/device', limit: 10, period: 1.minute) do |req|
    if req.path == '/api/v1/direct_uploads' && req.post?
      req.env['HTTP_X_DEVICE_ID']
    end
  end

  # General API throttle per IP
  # Limit: 300 requests per minute per IP (generous limit for normal usage)
  throttle('api/ip', limit: 300, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # General API throttle per device
  # Limit: 200 requests per minute per device
  throttle('api/device', limit: 200, period: 1.minute) do |req|
    req.env['HTTP_X_DEVICE_ID'] if req.path.start_with?('/api/')
  end

  # ========================================
  # Blocklists (Ban abusive clients)
  # ========================================

  # Block requests with suspicious patterns
  blocklist('block-bad-requests') do |req|
    # Block if User-Agent is missing (likely a bot)
    req.user_agent.blank? ||
    # Block if User-Agent is suspicious
    req.user_agent =~ /curl|wget|python|scrapy/i
  end

  # ========================================
  # Custom Response for Rate Limiting
  # ========================================

  # Customize the response when rate limit is exceeded
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

  # Customize the response when blocked
  self.blocklisted_responder = lambda do |env|
    [403, { 'Content-Type' => 'application/json' }, [{ error: '접근이 거부되었습니다.' }.to_json]]
  end

  # ========================================
  # Logging
  # ========================================

  # Log throttled requests
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
