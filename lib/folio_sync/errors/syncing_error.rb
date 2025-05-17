# frozen_string_literal: true

class FolioSync::Errors::SyncingError
  attr_reader :bib_id, :message

  def initialize(bib_id:, message:)
    @bib_id = bib_id
    @message = message
  end
end
