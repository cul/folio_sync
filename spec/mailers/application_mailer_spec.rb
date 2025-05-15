require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  let(:to_email) { 'test@example.com' }
  let(:subject) { 'FOLIO Sync Errors' }
  let(:downloading_errors) do
    [
      { resource_uri: '/repositories/2/resources/121332', error: 'Error downloading MARC XML' },
      { resource_uri: '/repositories/3/resources/421332', error: 'Timeout while fetching MARC data' }
    ]
  end
  let(:syncing_errors) do
    [
      { bib_id: '123', error: 'Failed to sync resource to FOLIO' },
      { bib_id: '456', error: 'Invalid MARC record' }
    ]
  end

  describe '#folio_sync_error_email' do
    before do
      allow(ApplicationMailer).to receive(:default).and_return(from: 'test-email@example.com')
    end

    let(:mail) do
      described_class.with(
        to: to_email,
        subject: subject,
        downloading_errors: downloading_errors,
        syncing_errors: syncing_errors
      ).folio_sync_error_email
    end

    it 'renders the correct subject' do
      expect(mail.subject).to eq(subject)
    end

    it 'sends the email to the correct recipient' do
      expect(mail.to).to eq([to_email])
    end

    it 'sets the correct sender email' do
      expect(mail.from).to eq(['test-email@example.com'])
    end

    it 'includes downloading errors in the email body' do
      downloading_errors.each do |error|
        expect(mail.body.encoded).to include("Resource URI: #{error[:resource_uri]}")
        expect(mail.body.encoded).to include("Error: #{error[:error]}")
      end
    end

    it 'includes syncing errors in the email body' do
      syncing_errors.each do |error|
        expect(mail.body.encoded).to include("Bib ID: #{error[:bib_id]}")
        expect(mail.body.encoded).to include("Error: #{error[:error]}")
      end
    end
  end
end