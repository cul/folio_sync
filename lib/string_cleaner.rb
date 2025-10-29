# frozen_string_literal: true

module StringCleaner
  def self.trailing_punctuation_and_whitespace(string)
    return nil if string.nil?

    stripped = string.strip
    stripped.end_with?('...') ? stripped : stripped.sub(%r{[,.:;/ ]+$}, '')
  end
end
