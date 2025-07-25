RSpec.describe FolioSync::ArchivesSpaceToFolio::MarcDownloader do
  let(:instance_key) { 'test_instance' }
  let(:downloader) { described_class.new(instance_key) }
  let(:aspace_client) { instance_double(FolioSync::ArchivesSpace::Client) }
  let(:folio_reader) { instance_double(FolioSync::Folio::Reader) }
  let(:record) { FactoryBot.create(:aspace_to_folio_record, :with_folio_data) }
  let(:marc_data) { '<record>MARC data</record>' }

  before do
    allow(FolioSync::ArchivesSpace::Client).to receive(:new).with(instance_key).and_return(aspace_client)
    allow(FolioSync::Folio::Reader).to receive(:new).and_return(folio_reader)
    allow(aspace_client).to receive(:fetch_marc_xml_resource).and_return(marc_data)
    allow(folio_reader).to receive(:get_marc_record_as_xml).with(record.folio_hrid).and_return(marc_data)
    allow(File).to receive(:binwrite)
  end

  describe '#initialize' do
    it 'initializes with the correct instance key and dependencies' do
      expect(downloader.instance_variable_get(:@instance_key)).to eq(instance_key)
      expect(downloader.instance_variable_get(:@aspace_client)).to eq(aspace_client)
      expect(downloader.instance_variable_get(:@folio_reader)).to eq(folio_reader)
      expect(downloader.downloading_errors).to eq([])
    end
  end

  describe '#download_pending_marc_records' do
    let(:pending_records) { [record] }

    before do
      allow(AspaceToFolioRecord).to receive(:where).and_return(pending_records)
    end

    it 'downloads MARC records for pending records' do
      expect(downloader).to receive(:download_marc_for_record).with(record)
      downloader.download_pending_marc_records
    end

    it 'logs errors when downloading fails' do
      allow(downloader).to receive(:download_marc_for_record).and_raise(StandardError, 'Test error')
      downloader.download_pending_marc_records

      expect(downloader.downloading_errors).to include(
        an_instance_of(FolioSync::Errors::DownloadingError).and(
          have_attributes(
            resource_uri: "repositories/#{record.repository_key}/resources/#{record.resource_key}",
            message: 'Test error'
          )
        )
      )
    end
  end

  describe '#download_marc_for_record' do
    it 'fetches and saves MARC records from ArchivesSpace and FOLIO' do
      expect(aspace_client).to receive(:fetch_marc_xml_resource).with(record.repository_key, record.resource_key)
      expect(folio_reader).to receive(:get_marc_record_as_xml).with(record.folio_hrid)
      expect(downloader).to receive(:save_marc_file).twice
      downloader.download_marc_for_record(record)
    end

    it 'skips FOLIO MARC download if folio_hrid is blank' do
      allow(record).to receive(:folio_hrid).and_return(nil)
      expect(folio_reader).not_to receive(:get_marc_record_as_xml)
      downloader.download_marc_for_record(record)
    end
  end

  describe '#save_marc_file' do
    it 'writes MARC data to the correct file path' do
      downloader.save_marc_file(File.join('/base/dir', 'path/to/file.xml'), marc_data)
      expect(File).to have_received(:binwrite).with('/base/dir/path/to/file.xml', marc_data)
    end
  end
end