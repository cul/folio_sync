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

  describe '#get_marc_record' do
    let(:response) { instance_double('Response', parsed: marc_record) }

    before do
      allow(instance).to receive(:find_marc_record).with(instance_record_hrid: bibid).and_return(response)
    end

    it 'fetches the MARC record for the given HRID' do
      result = instance.get_marc_record(bibid)
      expect(result).to eq(response)
    end
  end

  describe '#create_or_update_folio_record' do
    before do
      allow(instance).to receive(:get_marc_record).with(bibid).and_return(nil)
      allow(instance).to receive(:create_new_folio_marc_record)
      allow(instance).to receive(:update_existing_folio_marc_record)
    end

    it 'creates a new FOLIO MARC record if none exists' do
      instance.create_or_update_folio_record(bibid)
      expect(instance).to have_received(:create_new_folio_marc_record).with(bibid)
    end

    it 'updates an existing FOLIO MARC record if one exists' do
      allow(instance).to receive(:get_marc_record).with(bibid).and_return(marc_record)
      instance.create_or_update_folio_record(bibid)
      expect(instance).to have_received(:update_existing_folio_marc_record).with(bibid, marc_record)
    end
  end

  describe '#create_new_folio_marc_record' do
    let(:bibid) { '123456' }
    let(:marc_file_path) { Rails.root.join('tmp/marc_files', "#{bibid}.xml") }
    let(:mock_marc_xml) do
      <<-XML
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <controlfield tag="001">123456</controlfield>
          <datafield tag="245" ind1="1" ind2="0">
            <subfield code="a">Mock Title</subfield>
          </datafield>
        </record>
      XML
    end
  
    # Ensure the tmp/marc_files directory exists 
    # and create a mock MARC file
    before do
      FileUtils.mkdir_p(File.dirname(marc_file_path))
      File.write(marc_file_path, mock_marc_xml)
  
      allow(FolioSync::Folio::MarcRecord).to receive(:new).and_call_original
    end
  
    # Clean up the mock MARC file
    after do
      File.delete(marc_file_path) if File.exist?(marc_file_path)
    end
  
    it 'creates a new MARC record' do
      expect {
        instance.create_new_folio_marc_record(bibid)
      }.not_to raise_error
      expect(FolioSync::Folio::MarcRecord).to have_received(:new).with(bibid)
    end
  end
  
  describe '#update_existing_folio_marc_record' do
    let(:bibid) { '123456' }
    let(:marc_file_path) { Rails.root.join('tmp/marc_files', "#{bibid}.xml") }
    let(:mock_marc_xml) do
      <<-XML
        <record xmlns="http://www.loc.gov/MARC21/slim">
          <controlfield tag="001">123456</controlfield>
          <datafield tag="245" ind1="1" ind2="0">
            <subfield code="a">Mock Title</subfield>
          </datafield>
        </record>
      XML
    end
    let(:folio_marc) { double('FolioMarc') }
  
    # Ensure the tmp/marc_files directory exists 
    # and create a mock MARC file
    before do
      FileUtils.mkdir_p(File.dirname(marc_file_path))
      File.write(marc_file_path, mock_marc_xml)  
      allow(FolioSync::Folio::MarcRecord).to receive(:new).and_call_original
    end
  
    # Clean up the mock MARC file
    after do
      File.delete(marc_file_path) if File.exist?(marc_file_path)
    end
  
    it 'updates an existing MARC record' do
      expect {
        instance.update_existing_folio_marc_record(bibid, folio_marc)
      }.not_to raise_error
      expect(FolioSync::Folio::MarcRecord).to have_received(:new).with(bibid, folio_marc)
    end
  end
end
