class DistributedLockManager
  # REDIS COORDINATION KEY INVENTORY — the full pipeline key-space (nine
  # keys), with the consequence of losing each:
  #   ai_decision_lock:{conversation_id}     — flow lock (here); loss: brief
  #     concurrent-flow window, contained by token checks
  #   fragment_chain:{lock_token}            — duplicate-chain claim
  #     (FragmentSendJob); loss: bounded by the first-hop re-own gate
  #   decision_chain_alive:{conversation_id} — loop heartbeat (AiDecisionJob);
  #     loss: benign mass revival next sweep
  #   decision_chain_gen:{conversation_id}   — chain-fork guard (AiDecisionJob);
  #     loss: parked links die against the reset counter — the chain stays
  #     silent until the next restart, or the revival sweep once the
  #     heartbeat lapses (~2h worst case)
  #   farewell_pending:{conversation_id}     — parked-farewell slot
  #     (SeasonFarewellJob); loss: benign duplicate park
  #   periodic_tasks:scheduled               — hourly-chain guard
  #     (PeriodicTasksJob); loss: a boot can spawn a duplicate hourly chain
  #   season:rotation:lock                   — rotation mutex
  #     (RotationManagerService); loss mid-rotation could duplicate a season
  #     — the one non-benign loss here
  #   device_link:{code}                     — single-use identity-handoff
  #     slot (DeviceLinksController); loss: benign, the user requests a
  #     fresh code
  #   conversation_presence:{conversation_id} — live-subscription membership
  #     (ConversationChannel); loss: bounded early reset — the next periodic
  #     touch recreates the set, so only a teardown inside that window can
  #     clobber a live tab (corrected by its next visibility flip or init
  #     re-PUT)
  # Durable facts (farewell delivery) live in Postgres, not here.
  #
  # NOTE: FragmentSendJob's keep-lock-on-error strategy assumes every retry
  # stack in ai_pipeline_retry completes within this TTL (StandardError
  # ~60s, provider polynomial ~21s, Deadlocked ~15s — elapsed envelopes).
  # Each hop refreshes the lock. Retune those policies and this TTL together.
  DEFAULT_TTL = 300 # 5 minutes

  def self.ai_decision_key(conversation_id)
    "ai_decision_lock:#{conversation_id}"
  end

  # Atomically delete the lock only if it still holds the caller's token,
  # so a stale flow can never release a lock a newer flow owns
  RELEASE_SCRIPT = <<~LUA.freeze
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  LUA

  # Atomically extend the lock's TTL only if the caller still owns it —
  # doubles as an ownership check for long-running chained flows
  REFRESH_SCRIPT = <<~LUA.freeze
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("expire", KEYS[1], ARGV[2])
    else
      return 0
    end
  LUA

  # Returns the block's result, or false (without raising) if not acquired
  def self.with_lock(lock_key, ttl: DEFAULT_TTL)
    token = acquire(lock_key, ttl: ttl)
    return false unless token

    begin
      yield
    ensure
      release(lock_key, token)
    end
  end

  def self.acquire(lock_key, ttl: DEFAULT_TTL)
    token = SecureRandom.uuid
    acquired = redis do |conn|
      conn.set(lock_key, token, nx: true, ex: ttl)
    end

    acquired ? token : false
  end

  def self.release(lock_key, token)
    return 0 if token.blank?

    redis do |conn|
      conn.call('EVAL', RELEASE_SCRIPT, '1', lock_key, token)
    end
  end

  # Any-owner probe, unlike the token-guarded refresh
  def self.held?(lock_key)
    redis { |conn| conn.call('EXISTS', lock_key) } == 1
  end

  # TTL'd boolean markers — the transport for the heartbeat and pending-slot
  # flags in the key inventory above. Deliberately unconditional SETs (the
  # owners re-arm at will), NOT the NX/owner-guarded semantics of acquire/
  # claim; the arming/clearing PROTOCOL stays with each owner.
  def self.set_marker(key, ttl:)
    redis { |conn| conn.call('SET', key, '1', 'EX', ttl.to_s) }
  end

  def self.clear_marker(key)
    redis { |conn| conn.call('DEL', key) }
  end

  def self.marker?(key)
    redis { |conn| conn.call('EXISTS', key) } == 1
  end

  # Idempotently claim a key for an owner: succeeds when unclaimed or when
  # already claimed by the SAME owner — safe across ActiveJob retries, while
  # rejecting at-least-once enqueue duplicates that carry a different owner
  CLAIM_SCRIPT = <<~LUA.freeze
    local current = redis.call("get", KEYS[1])
    if current == false then
      redis.call("set", KEYS[1], ARGV[1], "EX", ARGV[2])
      return 1
    elseif current == ARGV[1] then
      return 1
    else
      return 0
    end
  LUA

  def self.claim(key, owner, ttl: DEFAULT_TTL)
    return false if owner.blank?

    redis { |conn| conn.call('EVAL', CLAIM_SCRIPT, '1', key, owner, ttl.to_s) } == 1
  end

  # Presence membership — which live subscriptions an entity has, as a
  # sorted set of member ids scored by last-touch epoch. Joining and touching
  # are the SAME operation (re-score the caller's own member, refresh the key
  # TTL), so entries from killed processes go stale — pruned at the next
  # teardown instead of poisoning the count forever — and a key lost to a
  # Redis restart is recreated by the next touch. Only the LAST live member's
  # teardown reads 0, so concurrent subscriptions never reset shared state
  # under each other.
  PRESENCE_LEAVE_SCRIPT = <<~LUA.freeze
    redis.call("zrem", KEYS[1], ARGV[1])
    redis.call("zremrangebyscore", KEYS[1], "-inf", ARGV[2])
    local remaining = redis.call("zcard", KEYS[1])
    if remaining == 0 then
      redis.call("del", KEYS[1])
    end
    return remaining
  LUA

  def self.presence_join(key, member, ttl:)
    redis do |conn|
      conn.multi do |m|
        m.call('ZADD', key, Time.current.to_i.to_s, member)
        m.call('EXPIRE', key, ttl.to_s)
      end
    end
  end

  def self.presence_leave(key, member, stale_before:)
    redis do |conn|
      conn.call('EVAL', PRESENCE_LEAVE_SCRIPT, '1', key, member, stale_before.to_i.to_s)
    end
  end

  # Monotonic chain-generation counter: restarts INCR it unconditionally,
  # continuations CAS-advance it per hop (below), and a link that fires
  # with a stale generation is a superseded fork that must die on arrival.
  # No TTL — a bounded set of tiny keys (one per conversation) whose expiry
  # would kill parked links.
  def self.bump_generation(key)
    redis { |conn| conn.call('INCR', key) }
  end

  def self.current_generation(key)
    redis { |conn| conn.call('GET', key) }.to_i
  end

  # Compare-and-advance: INCR only if the key still holds from_gen, else
  # return -1 without touching it. A missing key also returns -1 — a lost
  # counter must not be resurrected mid-chain.
  ADVANCE_SCRIPT = <<~LUA.freeze
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("incr", KEYS[1])
    else
      return -1
    end
  LUA

  def self.advance_generation(key, from_gen)
    redis { |conn| conn.call('EVAL', ADVANCE_SCRIPT, '1', key, from_gen.to_s) }
  end

  # Single-use handoff slots: NX so an improbable code collision retries
  # instead of silently overwriting an unexpired slot; GETDEL so a code is
  # consumable exactly once even under concurrent claims
  def self.store_once(key, value, ttl:)
    redis { |conn| conn.call('SET', key, value, 'NX', 'EX', ttl.to_s) } == 'OK'
  end

  def self.consume(key)
    redis { |conn| conn.call('GETDEL', key) }
  end

  def self.refresh(lock_key, token, ttl: DEFAULT_TTL)
    return false if token.blank?

    result = redis do |conn|
      conn.call('EVAL', REFRESH_SCRIPT, '1', lock_key, token, ttl.to_s)
    end

    result == 1
  end

  private

  def self.redis(&block)
    Sidekiq.redis(&block)
  end
end
