# frozen_string_literal: true

namespace :folio_sync do
  namespace :folio_to_hyacinth do
    task run: :environment do
      modified_since = ENV['modified_since']
      modified_since_num =
        if modified_since && !modified_since.strip.empty?
          begin
            Integer(modified_since)
          rescue ArgumentError
            puts 'Error: modified_since must be an integer (number of hours).'
            exit 1
          end
        end

      downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
      downloader.download_965hyacinth_marc_records(modified_since_num)

      if downloader.downloading_errors.present?
        puts "Errors encountered during MARC download: #{downloader.downloading_errors}"
        exit 1
      end
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
