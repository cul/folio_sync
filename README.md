# FOLIO Sync
The purpose of this application is to sync ArchivesSpace records to FOLIO. It automates retrieving unsuppressed resources from ArchivesSpace that were modified in the last 25 hours and syncing them to FOLIO. This ensures that FOLIO always has up-to-date records from ArchivesSpace.

## Setup
1. Install the required gems:
   ```bash
   bundle install
   ```

2. Create a configuration file for ArchivesSpace credentials:
   ```bash
   cp config/templates/archivesspace.yml config/archivesspace.yml
   ```
   Edit `config/archivesspace.yml` to include your ArchivesSpace API credentials. The script supports multiple instances.
   ```yaml
   development:
      instance1:
         base_url: "https://your-archivesspace-instance1/api"
         username: "your-username-1"
         password: "your-password-1"
         timeout: 60

     instance2:
         base_url: "https://your-archivesspace-instance2/api"
         username: "your-username-2"
         password: "your-password-2"
         timeout: 60

3. Create a configuration file for FOLIO API credentials:
   ```bash
   cp config/templates/folio.yml config/folio.yml
   ```
   Edit `config/folio.yml` to include your FOLIO API credentials:
   ```yaml
   development:
     base_url: "https://your-folio-instance"
     username: "your-username"
     password: "your-password"
     tenant: "your-tenant"
     timeout: 30
   ```

4. Create a configuration file for script-specific settings:
   ```bash
   cp config/templates/folio_sync.yml config/folio_sync.yml
   ```
   Edit `config/folio_sync.yml` to include settings specific to the script. The script supports multiple instances.
   ```yaml
   development:
     default_sender_email_address: "folio-sync@abc.com"
     job_log_entry_batch_size: 200 # Optional configuration, by default set to 100

    aspace_to_folio:
      batch_size: 500 # Optional configuration, by default set to 50
      marc_download_base_directory: <%= Rails.root.join('tmp/working_data/development/downloaded_files') %>
      prepared_marc_directory:  <%= Rails.root.join('tmp/working_data/development/prepared_files') %>
      developer_email_address: developer_email@example.com

      aspace_instances:
        instance1:
          marc_sync_email_addresses:
            - "user1@example.com"
        instance2:
          marc_sync_email_addresses:
            - "user2@example.com"
            - "user3@example.com"

## Running the Script
Most tasks require you to specify the `instance_key` (e.g., `instance1` or `instance2`) as an environment variable:

```bash
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1
```

## Tasks

### `folio_sync:aspace_to_folio:run`
Fetches ArchivesSpace MARC resources and syncs them to FOLIO. If any errors occur during downloading or syncing, an email is sent to the configured recipients.

#### Optional Environment Variables:
- **`modified_since`**: Accepts an integer representing the last `x` hours. Resources modified within the last `x` hours will be retrieved. If not supplied, all resources are retrieved regardless of their modification date.
- **`mode`**: Specifies which parts of the sync process to run. Valid values are:
  - `all` (default): Runs the complete process - download, prepare, and sync
  - `download`: Only fetches resources from ArchivesSpace and downloads MARC XML files
  - `prepare`: Only creates enhanced MARC records for export
  - `sync`: Only syncs prepared MARC records to FOLIO and updates ArchivesSpace records
- **`clear_downloads`**: If set to `true`, the downloads folder is cleared before processing. If set to `false`, the folder is not cleared. By default, `clear_downloads` is `true`.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1 modified_since=25 clear_downloads=false
```

#### Examples:
```bash
# Run with time filter
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1 modified_since=25

# Run the complete sync process (syncs all ArchivesSpace resources)
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1

# Only download MARC files from ArchivesSpace and FOLIO
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1 mode=download

# Only create enhanced MARC records
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1 mode=prepare

# Only sync already enhanced MARC records to FOLIO
bundle exec rake folio_sync:aspace_to_folio:run instance_key=instance1 mode=sync
```

---

### `folio_sync:aspace_to_folio:sync_exported_resources`
Syncs already downloaded MARC XML files from the directory specified in `folio_sync.yml` to FOLIO. If any errors occur during syncing, an email is sent to the configured recipients.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:sync_exported_resources instance_key=instance1
```

---

### `folio_sync:aspace_to_folio:process_marc_without_folio`
This task processes a single MARC XML file to create an enhanced MARC record. The enhanced record is generated based on the transformations defined in the `MarcRecordEnhancer` class.

#### Required Environment Variables:
- **`instance_key`**: The key identifying the ArchivesSpace instance.
- **`file_name`**: The name of the MARC XML file to process.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:process_marc_without_folio instance_key=<instance_key> file_name=<file_name>
```

#### Example:
```bash
bundle exec rake folio_sync:aspace_to_folio:process_marc_without_folio instance_key=instance1 file_name=test.xml
```

---

### `folio_sync:aspace_to_folio:process_marc_with_folio`
This task processes two MARC XML files (one from ArchivesSpace and one from FOLIO) to create an enhanced MARC record. The enhanced record is generated by merging and transforming data from both files using the `MarcRecordEnhancer` class.

#### Required Environment Variables:
- **`instance_key`**: The key identifying the ArchivesSpace instance.
- **`aspace_file`**: The name of the MARC XML file from ArchivesSpace.
- **`folio_file`**: The name of the MARC XML file from FOLIO.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:process_marc_with_folio instance_key=<instance_key> aspace_file=<aspace_file> folio_file=<folio_file>
```

#### Example:
```bash
bundle exec rake folio_sync:aspace_to_folio:process_marc_with_folio instance_key=instance1 aspace_file=aspace_record.xml folio_file=folio_record.xml
```

---

### `folio_sync:aspace_to_folio:email_test`
Sends a test email to the configured recipients to verify the email functionality.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:email_test instance_key=instance1
```

---

### `folio_sync:aspace_to_folio:folio_health_check`
Performs a health check on the FOLIO API to ensure it is reachable and functioning correctly.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:folio_health_check
```

## Other tasks unrelated to the FOLIO Sync
### `folio_hold_request_update:run`
This task runs a script that checks out all items linked to open, unfilled requests for a specified user barcode. The primary purpose is to temporarily change permanent holds on these items to temporary holds, which expire after 24 hours.

This is a temporary script that relies on the `folio_requests.yml` file to be added to the `/config` folder. For the exact structure of this file, please refer to `templates/folio_requests.yml`.

#### Required Environment Variables:
- **`repo_key`**: The key identifying the ArchivesSpace instance.

#### Usage:
```bash
bundle exec rake folio_hold_request_update:run repo_key=<repo_key_present_in_folio_requests_yml>
```

## Structure
This application was created using `rails new`. However, since we're using it as a script for now, we're not using Rails' MVC (Model-View-Controller) structure. For clarity, the app folder was kept but it's empty as we don't need its content.

Some of the default Rails setup was skipped during the initialization:
```bash
rails new folio_sync --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-record --skip-active-storage --skip-action-cable --skip-sprockets --skip-javascript --skip-hotwire --skip-jbuilder --skip-test --skip-system-test --skip-bootsnap
```

## Testing
Run the test suite using RSpec:
```bash
bundle exec rspec
```

## Linting
Run Rubocop:
```bash
bundle exec rubocop
```