require "nokogiri"
require "marc"

class FolioSync::Folio::MarcRecord
  attr_reader :aspace_record

  def initialize(bib_id, folio_marc)
    @aspace_record = MARC::XMLReader.new(File.join(File.dirname(__FILE__), "#{bib_id}.xml"), parser: "nokogiri")
    puts @aspace_record
  end

  private

  # This process will be different for other instances
  def process_cul_record
    # Temporarily implemented in test_record.rb
  end
end