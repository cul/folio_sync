# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer do
  let(:bibid) { '123456' }
  let(:marc_file_path) { Rails.root.join('tmp/marc_files', "#{bibid}.xml") }
  let(:mock_marc_xml) do
    <<-XML
      <record xmlns="http://www.loc.gov/MARC21/slim">
        <controlfield tag="001">123456</controlfield>
        <datafield tag="100" ind1="1" ind2=" ">
          <subfield code="a">Author Name</subfield>
          <subfield code="d">1990.</subfield>
          <subfield code="e">Editor</subfield>
        </datafield>
        <datafield tag="856" ind1="4" ind2="2">
          <subfield code="z">Old subfield z</subfield>
        </datafield>
        <datafield tag="110" ind1="2" ind2=" ">
          <subfield code="a">Corporate Name.</subfield>
        </datafield>
        <datafield tag="610" ind1="2" ind2=" ">
          <subfield code="a">Another Corporate Name.</subfield>
          <subfield code="b">Subfield b.</subfield>
        </datafield>
      </record>
    XML
  end
  let(:mock_folio_record) { double('MARC::Record') }

  before do
    # Ensure the tmp/marc_files directory exists
    # And create a mock MARC file
    FileUtils.mkdir_p(File.dirname(marc_file_path))
    File.write(marc_file_path, mock_marc_xml)

    # Mock the FOLIO client
    folio_client = instance_double(FolioSync::Folio::Client)
    allow(FolioSync::Folio::Client).to receive(:instance).and_return(folio_client)
    allow(folio_client).to receive(:get_marc_record).with(bibid).and_return(mock_folio_record)
  end

  # Clean up the mock MARC file
  after do
    File.delete(marc_file_path) if File.exist?(marc_file_path)
  end

  describe '#initialize' do
    it 'loads the MARC record from the file' do
      marc_record = described_class.new(bibid)
      expect(marc_record.marc_record).to be_a(MARC::Record)
      expect(marc_record.marc_record['001'].value).to eq('123456')
    end
  end

  describe '#enhance!' do
    it 'processes the MARC record and applies all transformations' do
      marc_record = described_class.new(bibid)
      processed_record = marc_record.enhance!

      # Check controlfield 001
      expect(processed_record['001'].value).to eq('123456')

      # Check controlfield 003
      expect(processed_record['003'].value).to eq('NNC')

      # Check datafield 100
      field_100 = processed_record['100']
      expect(field_100['d']).to eq('1990')
      expect(field_100['e']).to be_nil

      # Check datafield 856
      field_856 = processed_record['856']
      expect(field_856['z']).to be_nil
      expect(field_856['3']).to eq('Finding aid')

      # Check datafield 965
      field_965 = processed_record['965']
      expect(field_965['a']).to eq('965noexportAUTH')

      # Check datafield 110
      field_110 = processed_record['110']
      expect(field_110['a']).to eq('Corporate Name')

      # Check datafield 610
      field_610 = processed_record.fields('610').first
      expect(field_610['a']).to eq('Another Corporate Name.')
      expect(field_610['b']).to eq('Subfield b')
    end
  end
end
