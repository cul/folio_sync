# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  subject(:mail_subject) { 'FOLIO Sync Errors' }

  let(:to_email) { 'test@example.com' }

  let(:downloading_errors) do
    [
      FolioSync::Errors::DownloadingError.new(
        resource_uri: '/repositories/2/resources/121332',
        message: 'Error downloading MARC XML'
      ),
      FolioSync::Errors::DownloadingError.new(
        resource_uri: '/repositories/3/resources/421332',
        message: 'Timeout while fetching MARC data'
      )
    ]
  end
  let(:syncing_errors) do
    [
      FolioSync::Errors::SyncingError.new(
        resource_uri: '/repositories/4/resources/789',
        message: 'Failed to sync resource to FOLIO'
      ),
      FolioSync::Errors::SyncingError.new(
        resource_uri: '/repositories/5/resources/123',
        message: 'Invalid MARC record'
      )
    ]
  end

  describe '#folio_sync_error_email' do
    before do
      allow(described_class).to receive(:default).and_return(from: 'test-email@example.com')
    end

    let(:mail) do
      described_class.with(
        to: to_email,
        subject: mail_subject,
        downloading_errors: downloading_errors,
        syncing_errors: syncing_errors
      ).folio_sync_error_email
    end

    it 'renders the correct subject' do
      expect(mail.subject).to eq(mail_subject)
    end

    it 'sends the email to the correct recipient' do
      expect(mail.to).to eq([to_email])
    end

    it 'sets the correct sender email' do
      expect(mail.from).to eq(['test-email@example.com'])
    end

    it 'includes downloading errors in the email body' do
      downloading_errors.each do |error|
        expect(mail.body.encoded).to include("Resource URI: #{error.resource_uri}")
        expect(mail.body.encoded).to include("Error: #{error.message}")
      end
    end

    it 'includes syncing errors in the email body' do
      syncing_errors.each do |error|
        expect(mail.body.encoded).to include("Resource URI: #{error.resource_uri}")
        expect(mail.body.encoded).to include("Error: #{error.message}")
      end
    end
  end
end
