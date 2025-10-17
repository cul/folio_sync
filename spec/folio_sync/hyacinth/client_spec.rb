# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Hyacinth::Client do
  let(:url) { 'https://example-test.example.com' }
  let(:email) { 'testemail@example.com' }
  let(:password) { 'password' }

  let(:configuration) do
    FolioSync::Hyacinth::Configuration.new(
      url: url,
      email: email,
      password: password,
    )
  end
  let(:instance) { described_class.new(configuration) }

  before do
    allow(Rails.configuration).to receive(:hyacinth).and_return({
      'url' => url,
      'email' => email,
      'password' => password
    })
  end

  describe '.instance' do
    it 'returns a singleton instance of FolioSync::Hyacinth::Client' do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to be_a(described_class)
      expect(instance1).to eq(instance2)
    end
  end
end
