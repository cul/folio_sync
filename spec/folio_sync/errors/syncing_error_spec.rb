# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Errors::SyncingError do
  let(:resource_uri) { '/repositories/2/resources/1' }
  let(:message) { 'This is the message' }
  let(:instance) { described_class.new(resource_uri: resource_uri, message: message) }

  it 'can be instantiated' do
    expect(instance).to be_a(described_class)
  end

  describe '#resource_uri' do
    it 'returns the expected value' do
      expect(instance.resource_uri).to eq(resource_uri)
    end

  it 'allows resource_uri to be nil' do
    instance_without_uri = described_class.new(message: message)
    expect(instance_without_uri.resource_uri).to be_nil
    expect(instance_without_uri.message).to eq(message)
  end
  end

  describe '#message' do
    it 'returns the expected value' do
      expect(instance.message).to eq(message)
    end
  end
end
