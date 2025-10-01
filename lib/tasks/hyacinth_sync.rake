# frozen_string_literal: true

namespace :folio_sync do
  namespace :folio_to_hyacinth do
    task run: :environment do
      downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
      res = downloader.download_965hyacinth_marc_records(24)
      puts res
    end
  end
end
