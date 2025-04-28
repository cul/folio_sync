# FOLIO Sync
The purpose of this application is to sync Archives Space records to FOLIO.  It automates retrieving unsuppressed resources from Archives Space that were modified in the last 24 hours and syncing them to FOLIO. This ensures that FOLIO always has up-to-date records from Archives Space.

## Setup
1. Install the required gems:
   ```bash
   bundle install
   ```

2. Create a configuration file for Archives Space credentials:
   ```bash
   cp config/templates/archivesspace.yml config/archivesspace.yml
   ```
   Edit `config/archivesspace.yml` to include your Archives Space API credentials:
   ```yaml
   development:
     base_url: "https://your-archivesspace-instance/api"
     username: "your-username"
     password: "your-password"
   ```

## Running the script
```bash
rails folio_sync:run
```

## Structure
This application was created using `rails new`. However, since we're using it as a script for now, we're not using Rails' MVC (Model-View-Controller) structure. For clarity, the app folder was kept but it's empty as we don't need its content.

Some of the default Rails setup was skipped during the initialization:
```bash
rails new folio_sync --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-record --skip-active-storage --skip-action-cable --skip-sprockets --skip-javascript --skip-hotwire --skip-jbuilder --skip-test --skip-system-test --skip-bootsnap
```

## Testing
```bash
bundle exec rspec
```
