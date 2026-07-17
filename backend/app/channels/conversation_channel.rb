class ConversationChannel < ApplicationCable::Channel
  # Live-subscription membership TTL — bounds sets stranded by killed
  # processes; the periodic touch below keeps this subscription's membership
  # fresh, so long sessions never expire. This channel is broadcast-only:
  # typing/focus/reads arrive over REST, so no user activity flows here to
  # piggyback the refresh on.
  PRESENCE_TTL = 6.hours
  # Staleness threshold for members orphaned by a killed process — must
  # comfortably exceed the touch interval. Process kills INCLUDE deploys
  # (nothing runs cable teardown on Puma's graceful stop), which strand ALL
  # live members: any full departure within this window after a deploy skips
  # its focus reset, corrected only by that user's next init re-PUT.
  PRESENCE_STALE_AFTER = 40.minutes

  periodically :touch_presence, every: 15.minutes

  def subscribed
    conversation = find_conversation
    return reject unless conversation

    stream_for conversation
    join_presence

    Rails.logger.info "User subscribed to conversation #{conversation.id}"
  end

  def unsubscribed
    conversation = find_conversation
    return unless conversation

    # Presence-gated reset: only the LAST live member's teardown clears
    # is_focused, so multi-tab closes and heartbeat-late teardowns of
    # already-replaced connections can't clobber a live connection's focus —
    # while a stranded is_focused=true after truly leaving would silence
    # every push, and nothing else covers departure. Presence failures
    # deliberately degrade TOWARD the reset: a wrongly-reset live tab is
    # corrected by its next visibility flip or init re-PUT (a Redis-only
    # failure never drops the WebSocket, so no reconnect re-send fires),
    # whereas a skipped reset has no corrector until the user returns.
    remaining = begin
      DistributedLockManager.presence_leave(
        presence_key, presence_member, stale_before: PRESENCE_STALE_AFTER.ago
      )
    rescue StandardError => e
      Rails.logger.error "Presence leave failed (failing toward reset): #{e.message}"
      0
    end

    if remaining.zero?
      begin
        # The one teardown step whose failure degrades AWAY from reset (the
        # membership is already gone, so no later teardown re-reads zero for
        # this departure) — retry the transient class once
        retries ||= 0
        conversation.user_state&.update!(is_focused: false, typing: false)
      rescue StandardError => e
        if (retries += 1) == 1
          Rails.logger.warn "Focus reset failed, retrying once: #{e.message}"
          retry
        end
        raise
      end
    end

    Rails.logger.info "User unsubscribed from conversation #{conversation.id}"
  rescue StandardError => e
    # Nothing may escape unsubscribed: a raise aborts ActionCable's unguarded
    # teardown iteration, leaking other channels' callbacks and streams
    Rails.logger.error "Conversation teardown failed: #{e.message}"
  end

  private

  def find_conversation
    @conversation ||= current_user&.conversations&.find_by(id: params[:conversation_id])
  end

  def presence_key
    "conversation_presence:#{find_conversation.id}"
  end

  def presence_member
    @presence_member ||= SecureRandom.uuid
  end

  # Redis must never break the transport: a raise in subscribed leaves the
  # subscription registered-yet-unconfirmed and the client resubscribing
  # every 500ms forever. Presence is an enhancement — a missed join merely
  # degrades toward an early reset.
  def join_presence
    DistributedLockManager.presence_join(presence_key, presence_member, ttl: PRESENCE_TTL)
  rescue StandardError => e
    Rails.logger.error "Presence join failed: #{e.message}"
  end

  def touch_presence
    # An already-enqueued tick can execute after teardown (timers stop only
    # AFTER the unsubscribe callbacks) — it must not re-plant the member
    return if unsubscribed?
    return unless find_conversation

    join_presence
  end
end
