# frozen_string_literal: true

namespace :folio_sync do
  namespace :folio_to_hyacinth do
    task run: :environment do
      puts 'Starting Folio to Hyacinth sync task...'

      modified_since = ENV['modified_since']

      modified_since_sanitized =
        if modified_since && !modified_since.strip.empty?
          begin
            Integer(modified_since)
          rescue ArgumentError
            puts 'Error: modified_since must be an integer (number of hours).'
            exit 1
          end
        end

      clear_downloads = ENV['clear_downloads'].nil? || ENV['clear_downloads'] == 'true'
      puts "Will downloads be cleared? #{clear_downloads}"

      synchronizer = FolioSync::FolioToHyacinth::HyacinthSynchronizer.new
      synchronizer.clear_downloads! if clear_downloads
      synchronizer.download_and_sync_folio_to_hyacinth_records(modified_since_sanitized)

      if synchronizer.downloading_errors.any? || synchronizer.syncing_errors.any?
        puts 'Errors encountered during Folio to Hyacinth sync:'
        puts "Downloading Errors: #{synchronizer.downloading_errors}" if synchronizer.downloading_errors.any?
        puts "Syncing Errors: #{synchronizer.syncing_errors}" if synchronizer.syncing_errors.any?

        exit 1
      else
        puts 'Folio to Hyacinth sync completed successfully.'
      end
    end

    # Downloads FOLIO MARC records, skipping the syncing step
    task download_folio_marc_files: :environment do
      modified_since = ENV['modified_since']
      modified_since_sanitized =
        if modified_since && !modified_since.strip.empty?
          begin
            Integer(modified_since)
          rescue ArgumentError
            puts 'Error: modified_since must be an integer (number of hours).'
            exit 1
          end
        end

      downloader = FolioSync::FolioToHyacinth::MarcDownloader.new
      downloader.download_965hyacinth_marc_records(modified_since_sanitized)

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

    # Syncs all previously downloaded FOLIO MARC records to Hyacinth
    task sync_to_hyacinth: :environment do
      puts 'Starting Folio to Hyacinth sync task...'

      synchronizer = FolioSync::FolioToHyacinth::HyacinthSynchronizer.new
      synchronizer.prepare_and_sync_folio_to_hyacinth_records

      if synchronizer.syncing_errors.any?
        puts 'Errors encountered during Folio to Hyacinth sync:'
        puts "Syncing Errors: #{synchronizer.syncing_errors}" if synchronizer.syncing_errors.any?
        exit 1
      else
        puts 'Folio to Hyacinth sync completed successfully.'
      end
    end

    # Create MARC file with 965p field for testing
    task update_marc_with_project: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['filename'],
        'bundle exec rake folio_sync:folio_to_hyacinth:update_marc_with_project filename=123abc'
      )
      filename = ENV['filename']
      filepath = Rails.root.join(Rails.configuration.folio_to_hyacinth[:download_directory], filename)
      reader = MARC::Reader.new(filepath.to_s)
      marc_record = reader.first

      # Remove existing 965p fields
      marc_record.fields('965').each do |field|
        field.subfields.delete_if { |subfield| subfield.code == 'p' }
      end

      # Add 965p field with value academic_commons, ensure 965$a is set to 965hyacinth
      marc_record.append(MARC::DataField.new('965', ' ', ' ', ['a', '965hyacinth'], ['p', 'Test']))
      puts "Modified MARC record with new 965 field: #{marc_record.inspect}"

      new_filepath = Rails.root.join(Rails.configuration.folio_to_hyacinth[:download_directory], 'modified_marc.mrc')
      File.open(new_filepath, 'wb') do |file|
        writer = MARC::Writer.new(file)
        writer.write(marc_record)
        writer.close
      end
      reader = MARC::Reader.new(new_filepath.to_s)
      reader.each do |record|
        record.fields.each_by_tag(['965']) do |field|
          puts field
        end
      end
    end

    task create_new_hyacinth_record: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['filename'],
        'bundle exec rake folio_sync:folio_to_hyacinth:create_new_hyacinth_record filename=filename-in-tmp-dir'
      )
      filename = ENV['filename']
      filepath = Rails.root.join(Rails.configuration.folio_to_hyacinth[:download_directory], filename)

      record = FolioToHyacinthRecord.new(filepath.to_s)
      puts "Hyacinth record for file #{filename}: #{record.digital_object_data}"
    end

    task get_record_by_pid: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['pid'],
        'bundle exec rake folio_sync:folio_to_hyacinth:get_record_by_pid pid=123abc'
      )
      pid = ENV['pid']

      client = FolioSync::Hyacinth::Client.instance
      response = client.find_by_pid(pid)
      puts response.inspect
    end

    task encode: :environment do
      puts Base64.strict_encode64("#{Rails.configuration.hyacinth['email']}:#{Rails.configuration.hyacinth['password']}")
    end
  end
end
