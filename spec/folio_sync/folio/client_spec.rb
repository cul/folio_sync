# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Folio::Client do
  let(:base_url) { 'https://example-test.example.com' }
  let(:username) { 'username' }
  let(:password) { 'password' }
  let(:tenant) { 'tenant' }
  let(:timeout) { 10 }
  let(:configuration) do
    FolioApiClient::Configuration.new(
      url: base_url,
      username: username,
      password: password,
      tenant: tenant,
      timeout: timeout
    )
  end
  let(:instance) { described_class.new(configuration) }
  let(:bibid) { '123456' }
  let(:marc_record) { '<record><controlfield tag="001">123456</controlfield></record>' }

  before do
    allow(Rails.configuration).to receive(:folio).and_return({
      'base_url' => base_url,
      'username' => username,
      'password' => password,
      'tenant' => tenant,
      'timeout' => timeout
    })
  end

  describe '.instance' do
    it 'returns a singleton instance of FolioSync::Folio::Client' do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to be_a(described_class)
      expect(instance1).to eq(instance2)
    end
  end

  describe '#check_health' do
    let(:successful_response) { 'OK' }
    let(:error_response) { Faraday::BadRequestError.new('the server responded with status 400') }

    before do
      allow(instance).to receive(:get).with('/admin/health').and_return(successful_response)
    end

    it 'returns "OK" when the health check is successful' do
      result = instance.check_health
      expect(result).to eq(successful_response)
    end

    it 'raises an error when the health check fails' do
      allow(instance).to receive(:get).with('/admin/health').and_raise(error_response)

      expect {
        instance.check_health
      }.to raise_error(Faraday::BadRequestError, 'the server responded with status 400')
    end
  end
end
