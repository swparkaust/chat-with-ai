# Application-wide constants for Chat with AI
# These values control various timing, pagination, and threshold behaviors

module AppConstants
  # Fragment sending delays (in seconds)
  FRAGMENT_MIN_DELAY = 0.5
  FRAGMENT_MAX_DELAY = 8.0
  FRAGMENT_REEVALUATION_PROBABILITY = 0.3

  # Default timing delays for AI actions (in seconds)
  TIMING_DELAY_THINKING_BEFORE_RESPONSE = 1.0
  TIMING_DELAY_THINKING_BEFORE_READ_ONLY = 0.8
  TIMING_DELAY_THINKING_BEFORE_INITIATE = 1.5
  TIMING_DELAY_BETWEEN_FRAGMENTS = 2.5
  TIMING_DELAY_GENERIC_FALLBACK = 1.0

  # Character-based fallback delays for fragment sending (in seconds)
  TIMING_DELAY_FRAGMENT_LONG = 2.5    # > 20 characters
  TIMING_DELAY_FRAGMENT_MEDIUM = 1.5  # > 10 characters
  TIMING_DELAY_FRAGMENT_SHORT = 0.8   # <= 10 characters

  # AI decision delays (in seconds)
  AI_DECISION_MIN_DELAY = 30
  AI_DECISION_MAX_DELAY = 120
  AI_DECISION_FAILURE_RETRY_DELAY = 30  # Retry delay when AI decision fails
  AI_DECISION_BLOCKED_RETRY_DELAY = 60  # Retry delay when content is blocked

  # Active user thresholds
  ACTIVE_USER_WINDOW = 24.hours
  ACTIVE_USER_RECENT_ACTIVITY_WINDOW = 5.minutes

  # Typing indicator timeout
  TYPING_INDICATOR_TIMEOUT = 5.seconds

  # Season rotation timing
  SEASON_WARNING_PERIOD = 10.weeks
  SEASON_ROTATION_PERIOD = 3.months

  # Memory management
  MEMORY_RECENCY_THRESHOLD = 30.days

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

  # Scroll threshold (frontend, if needed in backend)
  SCROLL_THRESHOLD_PX = 50

  # AI Temperature values (controls randomness/creativity in AI responses)
  # Higher values (1.0) = more creative and varied, lower values (0.7) = more focused and deterministic

  # High creativity temperature - used for creative generation tasks
  AI_TEMPERATURE_CREATIVE = 1.0       # Persona generation, message generation, state evolution

  # Moderate temperature - used for decision-making and evaluation tasks
  AI_TEMPERATURE_FOCUSED = 0.7        # Timing decisions, fragment reevaluation
end
