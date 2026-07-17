module Interruptible
  extend ActiveSupport::Concern
  include AiRouterConcern

  INTERRUPT_POLL_INTERVAL = 0.25

  private

  # Returns { interrupted: true } or { interrupted: false, value:, started_at: }.
  # started_at is the canonical interrupt baseline: a non-interrupted return
  # proves no user message has arrived since that instant.
  def run_interruptible(conversation, lock_key, lock_token, description)
    started_at = Time.current
    worker = Thread.new { yield }

    # Aliveness is snapshotted BEFORE the interrupt check: if the worker
    # exits between the two, the loop runs one more iteration, so there is
    # always a final interrupt check dated after the worker finished
    loop do
      worker_was_alive = worker.alive?

      if conversation.user_messages_since?(started_at)
        Rails.logger.info "User interrupted during #{description}, cancelling and requeueing"
        worker.kill if worker.alive?
        DistributedLockManager.release(lock_key, lock_token)
        AiDecisionJob.restart_chain(conversation.id)
        return { interrupted: true }
      end

      break unless worker_was_alive

      sleep INTERRUPT_POLL_INTERVAL
    end

    { interrupted: false, value: worker.value, started_at: started_at }
  end

  def interruptible_thinking_pause(conversation, lock_key, lock_token, action_type, description)
    timing_decider = Ai::TimingDecider.new(router: ai_router)
    persona_state = conversation.season.persona_state

    # The timing decision (a seconds-long AI call) runs INSIDE the
    # worker so started_at precedes it — a message during the call
    # interrupts instead of slipping past the read-mark baseline
    run_interruptible(conversation, lock_key, lock_token, "#{description} thinking delay") do
      thinking_delay = timing_decider.get_timing_decision(action_type, persona_state)
      Rails.logger.info "AI will think for #{thinking_delay.round(2)}s before #{description}..."
      sleep thinking_delay
    end
  end
end
