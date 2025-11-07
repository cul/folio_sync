# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StringCleaner do
  describe '.trailing_punctuation_and_whitespace' do
    it 'returns nil for nil input' do
      expect(StringCleaner.trailing_punctuation_and_whitespace(nil)).to be_nil
    end

    it 'removes trailing punctuation and whitespace' do
      expect(StringCleaner.trailing_punctuation_and_whitespace('hello world,')).to eq('hello world')
      expect(StringCleaner.trailing_punctuation_and_whitespace('hello world.')).to eq('hello world')
      expect(StringCleaner.trailing_punctuation_and_whitespace('hello world:;/ ')).to eq('hello world')
      expect(StringCleaner.trailing_punctuation_and_whitespace('  hello world  ')).to eq('hello world')
    end

    it 'preserves ellipsis at the end' do
      expect(StringCleaner.trailing_punctuation_and_whitespace('hello world...')).to eq('hello world...')
    end

    it 'preserves internal punctuation' do
      expect(StringCleaner.trailing_punctuation_and_whitespace('hello, world.')).to eq('hello, world')
    end
  end
end