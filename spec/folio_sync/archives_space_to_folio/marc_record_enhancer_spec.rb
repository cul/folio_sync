# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer do
  include_context 'FolioSync directory setup'

  let(:hrid) { '123456' }
  let(:repo_key) { '123' }
  let(:resource_key) { '456' }
  let(:instance_key) { 'test' }
  let(:aspace_marc_path) { File.join(base_dir, instance_key, "#{repo_key}-##{resource_key}-aspace.xml") }
  let(:folio_marc_path) { File.join(base_dir, instance_key, "#{repo_key}-##{resource_key}-folio.xml") }
  let(:field_856_xml) do
    <<-XML
      <datafield tag="856" ind1="4" ind2="2">
        <subfield code="z">Old subfield z</subfield>
      </datafield>
    XML
  end
  let(:aspace_mock) do
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
  let(:folio_mock) do
    <<-XML
      <record xmlns="http://www.loc.gov/MARC21/slim">
        <controlfield tag="001">7890</controlfield>
        <datafield tag="100" ind1="1" ind2=" ">
          <subfield code="a">Author Name 2</subfield>
          <subfield code="d">1991.</subfield>
          <subfield code="e">Editor 2</subfield>
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

  before do
    File.write(aspace_marc_path, aspace_mock)
    File.write(folio_marc_path, folio_mock)

    # Mock FOLIO::Reader
    folio_reader = instance_double(FolioSync::Folio::Reader)
    allow(FolioSync::Folio::Reader).to receive(:new).and_return(folio_reader)
    allow(folio_reader).to receive(:get_marc_record_as_xml).with(hrid).and_return(folio_mock)
  end

  describe '#initialize' do
    it 'loads the MARC record from the file' do
      marc_record = described_class.new(aspace_marc_path, folio_marc_path, hrid, instance_key)
      expect(marc_record.marc_record).to be_a(MARC::Record)
      expect(marc_record.marc_record['001'].value).to eq('123456')
    end

    it 'stores the hrid' do
      marc_record = described_class.new(aspace_marc_path, folio_marc_path, hrid, instance_key)
      expect(marc_record.hrid).to eq(hrid)
    end
  end

  describe '#enhance_marc_record!' do
    let(:marc_record) { described_class.new(aspace_marc_path, folio_marc_path, hrid, instance_key) }
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
    let(:marc_record) { described_class.new(aspace_marc_path, folio_marc_path, hrid, instance_key) }
    let(:processed_record) { marc_record.enhance_marc_record! }

    it 'updates an existing 856 $3 value to "Finding aid"' do
      expect(processed_record['856']['3']).to eq('Finding aid')
    end
  end

  describe '#update_controlfield_001' do
    let(:marc_record) { described_class.new(aspace_marc_path, folio_marc_path, hrid, instance_key) }

    context 'when hrid is present' do
      it 'updates the value of controlfield 001 if it exists' do
        marc_record.marc_record.append(MARC::ControlField.new('001', 'old_value'))
        marc_record.send(:update_controlfield_001)
        expect(marc_record.marc_record['001'].value).to eq(hrid)
      end

      it 'adds a new controlfield 001 if it does not exist' do
        marc_record.marc_record.fields.delete_if { |field| field.tag == '001' }
        marc_record.send(:update_controlfield_001)
        expect(marc_record.marc_record['001'].value).to eq(hrid)
      end
    end

    context 'when hrid is nil' do
      let(:hrid) { nil }

      it 'removes controlfield 001 if it exists' do
        marc_record.marc_record.append(MARC::ControlField.new('001', 'old_value'))
        marc_record.send(:update_controlfield_001)
        expect(marc_record.marc_record['001']).to be_nil
      end
    end
  end

  describe 'helper methods' do
    let(:marc_record) { described_class.new(aspace_marc_path, folio_marc_path, hrid, instance_key) }

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
