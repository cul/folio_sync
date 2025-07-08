# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: Rails.configuration.folio_sync['default_sender_email_address']
  layout 'mailer'

  DISPLAY_LIMIT = 20

  ERROR_TYPES = [
    {
      key: :fetching_errors,
      title: 'Fetching from ArchivesSpace API errors'
    },
    {
      key: :saving_errors,
      title: 'Creating or updating local database records errors'
    },
    {
      key: :downloading_errors,
      title: 'Downloading MARC errors'
    },
    {
      key: :syncing_errors,
      title: 'Syncing resources to FOLIO errors'
    },
    {
      key: :linking_errors,
      title: 'Updating ArchivesSpace resources errors'
    }
  ].freeze

  def folio_sync_database_error_email
    body_content = <<~EMAIL
      The FOLIO Sync script has been interrupted due to a database integrity issue.

      One or more database records were found with missing folio_hrid values. To prevent the creation of duplicate entries in FOLIO, the synchronization process has been halted.

      Please investigate the following:
      1. Review recent synchronization logs for any errors or interruptions
      2. Check database records with nil folio_hrid values for instance: #{params[:instance_key]}
      3. Determine if records need to be manually corrected or re-synchronized
      4. Restart the sync process only after resolving the underlying issue

      This is an automated notification.
    EMAIL

    mail(
      to: params[:to],
      subject: params[:subject],
      body: body_content,
      content_type: 'text/plain'
    )
  end

  def folio_sync_error_email
    error_sections = ERROR_TYPES.map do |type|
      {
        title: type[:title],
        errors: params[type[:key]] || []
      }
    end

    body_content = format_folio_sync_errors(error_sections)

    mail(
      to: params[:to],
      subject: params[:subject],
      body: body_content,
      content_type: 'text/plain'
    )
  end

  private

  def format_folio_sync_errors(error_sections, display_limit: DISPLAY_LIMIT)
    total_errors_size = error_sections.sum { |section| section[:errors].size }

    summary_lines = [
      "One or more errors were encountered during FOLIO sync:\n",
      "Total Errors: #{total_errors_size}"
    ]
    error_sections.each do |section|
      summary_lines << "#{section[:title]}: #{section[:errors].size}"
    end
    summary_lines << "\n"

    body_content = summary_lines.join("\n")

    error_sections.each do |section|
      body_content += format_error_section(
        section[:errors],
        section[:title],
        display_limit
      )
    end

    body_content
  end

  def format_error_section(errors, title, display_limit)
    return '' if errors.blank?

    content = "======== #{title} ========\n"
    errors.first(display_limit).each do |error|
      content += "Resource URI: #{error.resource_uri}\n" if error.respond_to?(:resource_uri) && error.resource_uri.present?
      content += "Error: #{error.message}\n"
      content += "--------\n\n"
    end
    content += "+#{errors.size - display_limit} additional error(s)\n\n" if errors.size > display_limit
    content
  end
end
