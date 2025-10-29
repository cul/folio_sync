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

    task create_enhanced_marc_file: :environment do
      # FolioSync::Rake::EnvValidator.validate!(
      #   ['filename'],
      #   'bundle exec rake folio_sync:folio_to_hyacinth:create_enhanced_marc_file filename=filename-in-tmp-dir'
      # )
      # filename = ENV['filename']
      filename = 'bin3.marc'
      filepath = Rails.root.join('tmp/working_data/development/folio_to_hyacinth/downloaded_files', filename)

      record = FolioToHyacinthRecord.new(filepath.to_s)
      puts "Enhanced record for file #{filename}: #{record.digital_object_data}"
    end

    # Test Hyacinth API client and record creation/updating
    task create_or_update_record: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['hrid'],
        'bundle exec rake folio_sync:folio_to_hyacinth:download_single_file hrid=123abc'
      )
      folio_hrid = ENV['hrid']
      potential_clio_identifier = "clio#{folio_hrid}"

      client = FolioSync::Hyacinth::Client.instance

      # Check if item with given identifier already exists in Hyacinth
      results = client.find_by_identifier(potential_clio_identifier, { f: { digital_object_type_display_label_sim: ['Item'] } })
      puts "Found #{results.length} records with identifier #{potential_clio_identifier}."

      # TODO: Eventually this logic will be placed under FolioToHyacinth namespace
      if results.empty?
        puts 'No records found. Creating a new record in Hyacinth.'
        response = client.create_new_record(folio_hrid, publish: true)
        puts "Response from Hyacinth when creating record with hrid #{folio_hrid}: #{response.inspect}"
      elsif results.length == 1
        pid = results.first['pid']
        puts "Found 1 record with pid: #{pid}."

        # Before updating:
        # 1. Preserve existing identifiers
        # 2. Preserve existing projects

        # For now, just send the data back to test the update functionality
        response = client.update_existing_record(pid, results.first, publish: true)
        puts "Response from Hyacinth when updating record #{pid}: #{response.inspect}"
      else
        puts "Error: Found multiple records with identifier 'cul:3xsj3tx968'."
      end
    end

    task get_record_by_pid: :environment do
      FolioSync::Rake::EnvValidator.validate!(
        ['pid'],
        'bundle exec rake folio_sync:folio_to_hyacinth:download_single_file pid=123abc'
      )
      folio_pid = ENV['pid']

      client = FolioSync::Hyacinth::Client.instance
      response = client.find_by_pid(folio_pid)
      puts response.inspect
    end

    task encode: :environment do
      puts Base64.strict_encode64("#{Rails.configuration.hyacinth['email']}:#{Rails.configuration.hyacinth['password']}")
    end
  end
end
