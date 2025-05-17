# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Errors::SyncingError do
  let(:bib_id) { '123456789' }
  let(:message) { 'This is the message' }
  let(:instance) { described_class.new(bib_id: bib_id, message: message) }

  it 'can be instantiated' do
    expect(instance).to be_a(described_class)
  end

  describe '#bib_id' do
    it 'returns the expected value' do
      expect(instance.bib_id).to eq(bib_id)
    end
  end

  describe '#message' do
    it 'returns the expected value' do
      expect(instance.message).to eq(message)
    end
  end
end
