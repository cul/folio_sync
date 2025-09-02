# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Folio::ItemHoldUpdater do
  let(:folio_reader) { instance_double(FolioSync::Folio::Reader) }
  let(:folio_writer) { instance_double(FolioSync::Folio::Writer) }

  before do
    allow(FolioSync::Folio::Reader).to receive(:new).and_return(folio_reader)
    allow(FolioSync::Folio::Writer).to receive(:new).and_return(folio_writer)
  end

  describe '#initialize' do
    it 'initializes with correct dependencies' do
      instance = described_class.new
      expect(instance.instance_variable_get(:@folio_reader)).to eq(folio_reader)
      expect(instance.instance_variable_get(:@folio_writer)).to eq(folio_writer)
      expect(instance.instance_variable_get(:@updater_errors)).to eq([])
    end
  end

  describe '#remove_permanent_holds_from_items' do
    let(:items_to_check_out) do
      [
        { 'item' => { 'barcode' => 'ITEM123' } },
        { 'item' => { 'barcode' => 'ITEM456' } }
      ]
    end

    it 'checks out items when requests are found' do
      allow(folio_reader).to receive(:retrieve_circulation_requests).and_return(items_to_check_out)
      allow(folio_writer).to receive(:check_out_item_by_barcode)

      instance = described_class.new
      instance.remove_permanent_holds_from_items

      expect(folio_writer).to have_received(:check_out_item_by_barcode).with('ITEM123')
      expect(folio_writer).to have_received(:check_out_item_by_barcode).with('ITEM456')
    end

    it 'handles errors and continues processing' do
      allow(folio_reader).to receive(:retrieve_circulation_requests).and_return(items_to_check_out)
      allow(folio_writer).to receive(:check_out_item_by_barcode).with('ITEM123').and_raise(StandardError, 'Test error')
      allow(folio_writer).to receive(:check_out_item_by_barcode).with('ITEM456')

      instance = described_class.new
      instance.remove_permanent_holds_from_items

      errors = instance.instance_variable_get(:@updater_errors)
      expect(errors).to include('Error removing permanent hold from item with barcode ITEM123: Test error')
      expect(folio_writer).to have_received(:check_out_item_by_barcode).with('ITEM456')
    end
  end
end