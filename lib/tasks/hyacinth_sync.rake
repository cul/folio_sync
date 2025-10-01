# frozen_string_literal: true

namespace :folio_sync do
  namespace :folio_to_hyacinth do
    task run: :environment do
      downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
      res = downloader.download_965hyacinth_marc_records(24)
      puts res
    end

    task download_single_file: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['hrid'],
        'bundle exec rake folio_sync:folio_to_hyacinth:download_single_file hrid=123abc'
      )
      folio_hrid = ENV['hrid']

      downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
      downloader.download_single_965hyacinth_marc_record(folio_hrid)
    end
  end
end
