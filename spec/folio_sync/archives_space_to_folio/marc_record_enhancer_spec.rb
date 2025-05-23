# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer do
  let(:bibid) { '123456' }
  let(:instance_key) { 'test' }
  let(:base_dir) { 'tmp/downloaded_files' }
  let(:marc_file_path) { File.join(base_dir, instance_key, "#{bibid}.xml") }
  let(:field_856_xml) do
    <<-XML
      <datafield tag="856" ind1="4" ind2="2">
        <subfield code="z">Old subfield z</subfield>
      </datafield>
    XML
  end
  let(:mock_marc_xml) do
    <<-XML
      <record xmlns="http://www.loc.gov/MARC21/slim">
        <controlfield tag="001">123456</controlfield>
        <datafield tag="100" ind1="1" ind2=" ">
          <subfield code="a">Author Name</subfield>
          <subfield code="d">1990.</subfield>
          <subfield code="e">Editor</subfield>
        </datafield>
        #{field_856_xml}
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
  let(:folio_sync_config) do
    {
      'marc_download_base_directory' => base_dir
    }
  end
  let(:archivesspace_config) do
    {
      'test' => {
        base_url: 'https://example-test.library.edu/api',
        username: 'test-user',
        password: 'test-password',
        timeout: 60
      }
    }
  end

  before do
    allow(Rails.configuration).to receive_messages(folio_sync: folio_sync_config, archivesspace: archivesspace_config)

    # Create the directory structure if it doesn't exist
    FileUtils.mkdir_p(File.dirname(marc_file_path))
    File.write(marc_file_path, mock_marc_xml)

    # Mock FOLIO::Reader
    folio_reader = instance_double(FolioSync::Folio::Reader)
    allow(FolioSync::Folio::Reader).to receive(:new).and_return(folio_reader)
    allow(folio_reader).to receive(:get_marc_record).with(bibid).and_return(mock_folio_record)
  end

  # Clean up the mock MARC file and directory
  after do
    FileUtils.rm_rf(File.join(base_dir, instance_key)) if File.exist?(File.join(base_dir, instance_key))
  end

  describe '#initialize' do
    it 'loads the MARC record from the file' do
      marc_record = described_class.new(bibid, instance_key)
      expect(marc_record.marc_record).to be_a(MARC::Record)
      expect(marc_record.marc_record['001'].value).to eq('123456')
    end

    it 'stores the bibid' do
      marc_record = described_class.new(bibid, instance_key)
      expect(marc_record.bibid).to eq(bibid)
    end
  end

  describe '#enhance_marc_record!' do
    let(:marc_record) { described_class.new(bibid, instance_key) }
    let(:processed_record) { marc_record.enhance_marc_record! }

    it 'processes the MARC record and applies all transformations' do
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

  describe '#update_datafield_856' do
    let(:field_856_xml) do
      <<-XML
        <datafield tag="856" ind1="4" ind2="2">
          <subfield code="z">Old subfield z</subfield>
          <subfield code="3">Lemon aid</subfield>
        </datafield>
      XML
    end
    let(:marc_record) { described_class.new(bibid, instance_key) }
    let(:processed_record) { marc_record.enhance_marc_record! }

    it 'updates an existing 856 $3 value to "Finding aid"' do
      expect(processed_record['856']['3']).to eq('Finding aid')
    end
  end

  describe 'helper methods' do
    let(:marc_record) { described_class.new(bibid, instance_key) }

    describe '#remove_trailing_commas' do
      it 'removes trailing periods' do
        result = marc_record.send(:remove_trailing_commas, 'Text with period.')
        expect(result).to eq('Text with period')
      end

      it 'does not modify text without trailing periods' do
        result = marc_record.send(:remove_trailing_commas, 'Text without')
        expect(result).to eq('Text without')
      end
    end
  end
end
