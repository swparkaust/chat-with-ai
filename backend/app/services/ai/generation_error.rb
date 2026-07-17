module Ai
  # Application-level failure signal for AI calls whose output the pipeline
  # cannot proceed without (message and persona generation). Adapters never
  # raise — they return AiResponse with nil text — so this is raised by the
  # consuming service and drives the ai_pipeline_retry policies.
  class GenerationError < StandardError; end
end
