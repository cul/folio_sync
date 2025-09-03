# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioHoldUpdatesErrorMailer, type: :mailer do
  subject(:mail_subject) { 'FOLIO Hold Updates Errors' }
  let(:to_email) { 'test@example.com' }
  let(:errors) { [ "Something went wrong  with item with barcode ITEM123", "Another error occurred with item with barcode ITEM456"] }

  describe '#hold_update_error_email' do
    before do
      allow(described_class).to receive(:default).and_return(from: 'test-email@example.com')
    end

    let(:mail) do
      described_class.with(
        to: to_email,
        subject: mail_subject,
        errors: errors
      ).hold_update_error_email
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
  end
end
