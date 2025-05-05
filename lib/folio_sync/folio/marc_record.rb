require "nokogiri"
require "marc"

class FolioSync::Folio::MarcRecord
  attr_reader :aspace_record

  def initialize(bib_id, folio_marc)
    aspace_marc_path = Rails.root.join("tmp/marc_files", "#{bib_id}.xml").to_s
    @aspace_record = MARC::XMLReader.new(aspace_marc_path, parser: "nokogiri")
    puts @aspace_record
  end

  private

  # This process will be different for other instances
  def process_cul_record
    # Temporarily implemented in test_record.rb
  end
end