# Application-wide constants for Chat with AI
# These values control various timing, pagination, and threshold behaviors

module AppConstants
  # Fragment sending delays (in seconds)
  FRAGMENT_MIN_DELAY = 0.5
  FRAGMENT_MAX_DELAY = 8.0
  FRAGMENT_REEVALUATION_PROBABILITY = 0.3

  # Thinking pause bounds (in seconds)
  THINKING_MIN_DELAY = 0.5
  THINKING_MAX_DELAY = 8.0

  # Default timing delays for AI actions (in seconds)
  TIMING_DELAY_THINKING_BEFORE_RESPONSE = 1.0
  TIMING_DELAY_THINKING_BEFORE_READ_ONLY = 0.8
  TIMING_DELAY_THINKING_BEFORE_INITIATE = 1.5
  TIMING_DELAY_GENERIC_FALLBACK = 1.0

  # Character-based fallback delays for fragment sending (in seconds)
  TIMING_DELAY_FRAGMENT_LONG = 2.5    # > 20 characters
  TIMING_DELAY_FRAGMENT_MEDIUM = 1.5  # > 10 characters
  TIMING_DELAY_FRAGMENT_SHORT = 0.8   # <= 10 characters

  # AI decision delays (in seconds)
  AI_DECISION_MIN_DELAY = 30
  AI_DECISION_MAX_DELAY = 120
  AI_DECISION_FAILURE_RETRY_DELAY = 30  # Retry delay when AI decision fails

  # Output budget for every AI call (the router default). Must stay generous:
  # some models count internal thinking tokens against it, and a small budget
  # yields truncated/blank output — the failure mode the blank guards catch.
  AI_MAX_OUTPUT_TOKENS = 16384

  # Bounds for the AI-chosen wait between decisions (in seconds) —
  # interpolated into the decision prompt AND enforced by the clamp; the
  # wait branch re-stamps AiDecisionJob's heartbeat sized to the chosen
  # wait. The hour-long ceiling is the idle-cost lever: the decision loop
  # dominates AI spend, and new user messages restart the chain immediately
  # regardless of a parked wait, so a long wait never delays a reply.
  AI_WAIT_MIN_SECONDS = 10
  AI_WAIT_MAX_SECONDS = 3600

  # Active user thresholds
  ACTIVE_USER_WINDOW = 24.hours

  # Typing indicator timeout
  TYPING_INDICATOR_TIMEOUT = 5.seconds

  # Season rotation timing
  SEASON_WARNING_PERIOD = 10.weeks
  SEASON_ROTATION_PERIOD = 3.months

  # Message pagination and limits
  MESSAGE_PAGE_SIZE_MAX = 200
  MESSAGE_PAGE_SIZE_DEFAULT = 100
  MESSAGE_CONTENT_MAX_LENGTH = 10000

  # AI context message history limits
  CONTEXT_MESSAGES_FOR_RESPONSE = 30      # Full conversation context for generating responses
  CONTEXT_MESSAGES_FOR_INITIATION = 20    # Context when AI initiates conversation
  CONTEXT_MESSAGES_FOR_DECISION = 20      # Context for deciding next action
  CONTEXT_MESSAGES_FOR_KEYWORDS = 5       # Recent messages for extracting keywords
  CONTEXT_MESSAGES_FOR_REEVALUATION = 10  # Context for dynamic fragment reevaluation
  CONTEXT_MEMORIES_LIMIT = 5              # Max relevant memories to include in context

end
