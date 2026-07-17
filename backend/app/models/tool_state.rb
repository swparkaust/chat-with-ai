class ToolState < ApplicationRecord
  include JsonbStateAccessor

  belongs_to :season

  # No uniqueness validation — the (season_id, tool_name) unique index is the
  # sole enforcement. ToolManager#register_tool relies on create_or_find_by!,
  # which per Rails docs cannot coexist with a uniqueness validation: the
  # validation raises RecordInvalid before the index fallback can fire.
  validates :tool_name, presence: true
  validates :state_data, exclusion: { in: [nil] }

  scope :for_tool, ->(tool_name) { where(tool_name: tool_name) }
end
