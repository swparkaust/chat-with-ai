# frozen_string_literal: true

module InputSanitization
  extend ActiveSupport::Concern

  private

  def sanitize_content(raw_content)
    return nil if raw_content.nil?

    content = raw_content.to_s

    content = content.tr("\u0000", '')
    content = content.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')

    content = content.unicode_normalize(:nfc)

    content = content.gsub(/[\u200B-\u200D\uFEFF]/, '')

    content = content.gsub(/\n{4,}/, "\n\n\n")

    content = content.gsub(/ {6,}/, '     ')

    content.strip
  end
end
