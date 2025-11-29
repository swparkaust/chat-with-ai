class DistributedLockManager
  class LockNotAcquiredError < StandardError; end
  class LockTimeoutError < StandardError; end

  DEFAULT_TTL = 300 # 5 minutes
  DEFAULT_RETRY_DELAY = 0.1 # 100ms

  # Execute a block with a distributed lock, ensuring automatic cleanup
  #
  # @param lock_key [String] Unique identifier for the lock
  # @param ttl [Integer] Time-to-live for the lock in seconds
  # @param raise_on_failure [Boolean] Whether to raise exception if lock not acquired
  # @yield Block to execute while holding the lock
  # @return [Object] Result of the block execution
  #
  # @example
  #   DistributedLockManager.with_lock("my_resource") do
  #     # Critical section code here
  #   end
  def self.with_lock(lock_key, ttl: DEFAULT_TTL, raise_on_failure: false)
    lock_acquired = acquire(lock_key, ttl: ttl)

    if !lock_acquired && raise_on_failure
      raise LockNotAcquiredError, "Failed to acquire lock: #{lock_key}"
    end

    return false unless lock_acquired

    begin
      yield
    ensure
      release(lock_key)
    end
  end

  # Acquire a distributed lock
  #
  # @param lock_key [String] Unique identifier for the lock
  # @param ttl [Integer] Time-to-live for the lock in seconds
  # @return [Boolean] True if lock was acquired, false otherwise
  def self.acquire(lock_key, ttl: DEFAULT_TTL)
    redis do |conn|
      conn.set(lock_key, Time.current.to_i, nx: true, ex: ttl)
    end
  end

  # Release a distributed lock
  #
  # @param lock_key [String] Unique identifier for the lock
  # @return [Integer] Number of keys deleted (0 or 1)
  def self.release(lock_key)
    redis do |conn|
      conn.del(lock_key)
    end
  end

  # Check if a lock is currently held
  #
  # @param lock_key [String] Unique identifier for the lock
  # @return [Boolean] True if lock exists, false otherwise
  def self.locked?(lock_key)
    redis do |conn|
      conn.exists?(lock_key)
    end
  end

  # Wait for a lock to be released, then acquire it
  #
  # @param lock_key [String] Unique identifier for the lock
  # @param ttl [Integer] Time-to-live for the lock in seconds
  # @param max_wait [Integer] Maximum time to wait for lock in seconds
  # @param retry_delay [Float] Delay between retry attempts in seconds
  # @return [Boolean] True if lock was acquired, false if timeout
  def self.wait_and_acquire(lock_key, ttl: DEFAULT_TTL, max_wait: 30, retry_delay: DEFAULT_RETRY_DELAY)
    deadline = Time.current + max_wait

    loop do
      return true if acquire(lock_key, ttl: ttl)

      if Time.current >= deadline
        Rails.logger.warn "Lock wait timeout for #{lock_key} after #{max_wait}s"
        return false
      end

      sleep retry_delay
    end
  end

  private

  def self.redis(&block)
    Sidekiq.redis(&block)
  end
end
