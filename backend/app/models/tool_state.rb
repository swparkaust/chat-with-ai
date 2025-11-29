class ToolState < ApplicationRecord
  include JsonbStateAccessor

  belongs_to :season

  validates :tool_name, presence: true, uniqueness: { scope: :season_id }
  validates :state_data, exclusion: { in: [nil] }

  scope :for_tool, ->(tool_name) { where(tool_name: tool_name) }
end
