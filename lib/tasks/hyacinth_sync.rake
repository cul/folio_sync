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

    task sync_to_hyacinth: :environment do
      puts "Starting Folio to Hyacinth sync task..."
      file_dir = Rails.root.join('tmp/working_data/development/folio_to_hyacinth/downloaded_files')

      # For each MARC file in the download directory, create or update the corresponding Hyacinth record
      Dir.glob(File.join(file_dir, '*.mrc')).each do |marc_file_path|
        puts "Processing MARC file: #{marc_file_path}"

        # Check if the record already exists in Hyacinth
        folio_hrid = File.basename(marc_file_path, '.mrc')
        potential_clio_identifier = "clio#{folio_hrid}"
        client = FolioSync::Hyacinth::Client.instance
        results = client.find_by_identifier(potential_clio_identifier, { f: { digital_object_type_display_label_sim: ['Item'] } })
        puts "Found #{results.length} records with identifier #{potential_clio_identifier}."

        # TODO: Eventually this logic will be placed under FolioToHyacinth namespace
        if results.empty?
          puts 'No records found. Creating a new record in Hyacinth.'
          new_record = FolioToHyacinthRecord.new(marc_file_path)
          puts "New record digital object data: #{new_record.digital_object_data}"
          response = client.create_new_record(new_record.digital_object_data, publish: true)
          puts "Response from Hyacinth when creating record with hrid #{folio_hrid}: #{response.inspect}"
        elsif results.length == 1
          pid = results.first['pid']
          puts "Found 1 record with pid: #{pid}."

          updated_record = FolioToHyacinthRecord.new(marc_file_path, results.first)
          # response = client.update_existing_record(pid, updated_record.digital_object_data, publish: true)
          # puts "Response from Hyacinth when updating record #{pid}: #{response.inspect}"
        else
          puts "Error: Found multiple records with identifier #{potential_clio_identifier}."
        end
      end
    end

    # Create MARC file with 965p field for testing
    task create_marc: :environment do
      filename = 'bin3.mrc'
      filepath = Rails.root.join(Rails.configuration.folio_to_hyacinth[:download_directory], filename)
      reader = MARC::Reader.new(filepath.to_s)
      marc_record = reader.first

      # Add 965p field with value academic_commons, ensure 965$a is set to 965hyacinth
      marc_record.append(MARC::DataField.new('965', ' ', ' ', ['a', '965hyacinth'], ['p', 'academic_commons']))

      puts "Modified MARC record with new 965 field: #{marc_record.inspect}"

      new_filepath = Rails.root.join(Rails.configuration.folio_to_hyacinth[:download_directory], 'modified_marc.mrc')
      File.open(new_filepath, 'wb') do |file|
        writer = MARC::Writer.new(file)
        writer.write(marc_record)
        writer.close
      end
      puts marc_record
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
