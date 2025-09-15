# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolioSync::Folio::HoldingsCreator do
  let(:folio_writer) { instance_double(FolioSync::Folio::Writer) }
  let(:instance_id) { 'test-instance-id-123' }
  let(:holdings_metadata) do
    {
      holdings_call_number: 'call-num-123',
      permanent_location: 'main_library'
    }
  end
  let(:holdings_creator) { described_class.new(folio_writer) }

  before do
    allow(Rails.configuration).to receive(:folio_holdings).and_return(
      location_codes: {
        main_library: 'location-id-123',
        special_collections: 'location-id-456'
      }
    )
  end

  describe '#initialize' do
    it 'initializes with provided folio_writer' do
      expect(holdings_creator.instance_variable_get(:@folio_writer)).to eq(folio_writer)
    end

    it 'initializes with default folio_writer when none provided' do
      instance = described_class.new
      expect(instance.instance_variable_get(:@folio_writer)).to be_a(FolioSync::Folio::Writer)
    end
  end

  describe '#create_holdings_for_instance' do
    let(:expected_response) { { 'id' => 'holdings-id-123' } }

    context 'with valid parameters' do
      before do
        allow(folio_writer).to receive(:create_holdings_record).and_return(expected_response)
      end

      it 'creates holdings record successfully' do
        result = holdings_creator.create_holdings_for_instance(instance_id, holdings_metadata)

        expect(folio_writer).to have_received(:create_holdings_record).with(
          instance_id,
          'call-num-123',
          'location-id-123'
        )
        expect(result).to eq(expected_response)
      end
    end

    context 'with missing holdings_call_number' do
      let(:invalid_metadata) { { permanent_location: 'main_library' } }

      it 'raises error for missing call number' do
        expect do
          holdings_creator.create_holdings_for_instance(instance_id, invalid_metadata)
        end.to raise_error('Missing required holdings metadata: holdings_call_number')
      end
    end

    context 'with missing permanent_location' do
      let(:invalid_metadata) { { holdings_call_number: 'call-num-123' } }

      it 'raises error for missing location' do
        expect do
          holdings_creator.create_holdings_for_instance(instance_id, invalid_metadata)
        end.to raise_error('Missing required holdings metadata: permanent_location')
      end
    end

    context 'with multiple missing fields' do
      let(:invalid_metadata) { {} }

      it 'raises error listing all missing fields' do
        expect do
          holdings_creator.create_holdings_for_instance(instance_id, invalid_metadata)
        end.to raise_error('Missing required holdings metadata: holdings_call_number, permanent_location')
      end
    end

    context 'with unknown location code' do
      let(:unknown_location_metadata) do
        {
          holdings_call_number: 'call-num-123',
          permanent_location: 'unknown_location'
        }
      end

      it 'raises error for unknown location code' do
        expect do
          holdings_creator.create_holdings_for_instance(instance_id, unknown_location_metadata)
        end.to raise_error('Unknown location code: unknown_location')
      end
    end
  end
end