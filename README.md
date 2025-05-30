# FOLIO Sync
The purpose of this application is to sync ArchivesSpace records to FOLIO.  It automates retrieving unsuppressed resources from ArchivesSpace that were modified in the last 24 hours and syncing them to FOLIO. This ensures that FOLIO always has up-to-date records from ArchivesSpace.

## Setup
1. Install the required gems:
   ```bash
   bundle install
   ```

2. Create a configuration file for ArchivesSpace credentials:
   ```bash
   cp config/templates/archivesspace.yml config/archivesspace.yml
   ```
   Edit `config/archivesspace.yml` to include your ArchivesSpace API credentials:
   ```yaml
   development:
     base_url: "https://your-archivesspace-instance/api"
     username: "your-username"
     password: "your-password"
   ```

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
   Edit `config/folio_sync.yml` to include settings specific to the script:
   ```yaml
   development:
     marc_download_directory: <%= Rails.root.join('tmp/development/marc_files') %>
     default_sender_email_address: "no-reply@example.com"
     marc_sync_email_addresses:
       - "admin@example.com"
   ```

## Running the Script
```bash
bundle exec rake folio_sync:aspace_to_folio:run
```

## Tasks

### `folio_sync:aspace_to_folio:run`
Fetches ArchivesSpace MARC resources modified in the last 24 hours and syncs them to FOLIO. If any errors occur during downloading or syncing, an email is sent to the configured recipients.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:run
```

---

### `folio_sync:aspace_to_folio:sync_exported_resources`
Syncs already downloaded MARC XML files from the directory specified in `folio_sync.yml` to FOLIO. If any errors occur during syncing, an email is sent to the configured recipients.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:sync_exported_resources
```

---

### `folio_sync:aspace_to_folio:process_marc_xml`
This task allows you to test the processing of a MARC XML file for a specific `bib_id`. It reads the MARC XML file from the `marc_download_directory` specified in `folio_sync.yml`, processes it, and applies the necessary transformations.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:process_marc_xml bib_id=<bib_id>
```

#### Example:
```bash
bundle exec rake folio_sync:aspace_to_folio:process_marc_xml bib_id=123456789
```

---

### `folio_sync:aspace_to_folio:folio_health_check`
Performs a health check on the FOLIO API to ensure it is reachable and functioning correctly.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:folio_health_check
```

---

### `folio_sync:aspace_to_folio:email_test`
Sends a test email to the configured recipients to verify the email functionality.

#### Usage:
```bash
bundle exec rake folio_sync:aspace_to_folio:email_test
```

---

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
