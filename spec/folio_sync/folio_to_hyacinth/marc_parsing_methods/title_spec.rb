# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::FolioToHyacinth::MarcParsingMethods::Title do
  let(:test_class) do
    Class.new do
      include FolioSync::FolioToHyacinth::MarcParsingMethods
      include FolioSync::FolioToHyacinth::MarcParsingMethods::Title

      def initialize
        @digital_object_data = { 'dynamic_field_data' => {} }
      end

      def dynamic_field_data
        @digital_object_data['dynamic_field_data']
      end
    end
  end

  let(:instance) { test_class.new }

  it 'registers add_title as a parsing method' do
    expect(test_class.registered_parsing_methods).to include(:add_title)
  end

  it 'does nothing when 245 field is missing' do
    marc_record = MARC::Record.new
    instance.add_title(marc_record, nil)
    expect(instance.dynamic_field_data['title']).to be_nil
  end

  it 'extracts title and splits it into non-sort and sort portions' do
    marc_record = MARC::Record.new
    marc_record.append(MARC::DataField.new('245', '0', '4', ['a', 'The Great Book']))

    instance.add_title(marc_record, nil)

    expect(instance.dynamic_field_data['title'].first).to eq(
      'title_non_sort_portion' => 'The ',
      'title_sort_portion' => 'Great Book'
    )
  end

  it 'combines $a and $b subfields' do
    marc_record = MARC::Record.new
    marc_record.append(MARC::DataField.new('245', '0', '0', ['a', 'Main Title'], ['b', 'subtitle']))

    instance.add_title(marc_record, nil)

    expect(instance.dynamic_field_data['title'].first['title_sort_portion']).to eq('Main Title subtitle')
  end

  it 'uses $f instead of $b for oral_history ruleset' do
    marc_record = MARC::Record.new
    marc_record.append(MARC::DataField.new('245', '0', '0',
      ['a', 'Interview'],
      ['b', 'ignored'],
      ['f', '1965']
    ))

    instance.add_title(marc_record, 'oral_history')

    title = instance.dynamic_field_data['title'].first['title_sort_portion']
    expect(title).to eq('Interview 1965')
  end
end
