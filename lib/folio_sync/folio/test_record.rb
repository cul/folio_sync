class FolioSync::Folio::TestRecord
  attr_reader :marc_record, :bibid

  def initialize(bibid)
    @bibid = bibid
    
    # Uncomment the following line later
    # aspace_record = MARC::XMLReader.new(File.join(File.dirname(__FILE__), "#{bibid}.xml"), parser: "nokogiri")
    aspace_record = MARC::XMLReader.new(File.join(File.dirname(__FILE__), "test.xml"), parser: "nokogiri")
    @marc_record = aspace_record.first
  end

  def process_record
    puts "Processing..."
    add_controlfield_001
    add_controlfield_003
    update_datafield_100 

    update_datafield_856
    add_965noexportAUTH
    # corpname_punctuation # TODO: implement
    
    puts @marc_record
    @marc_record
  end

  # Add bibid to controlfield 001 if it doesn't exist
  def add_controlfield_001
    unless @marc_record['001']
      ctrl_field = MARC::ControlField.new('001', @bibid)
      @marc_record.append(ctrl_field)
    end
  end

  # Add NNC to controlfield 003 if it doesn't exist
  def add_controlfield_003
    unless @marc_record['003']
      ctrl_field = MARC::ControlField.new('003', 'NNC')
      @marc_record.append(ctrl_field)
    end
  end

  # Update datafield 100 - remove trailing punctuation from subfield d and remove subfield e
  def update_datafield_100
    field_100 = @marc_record['100']
    return unless field_100

    field_100.subfields.delete_if { |sf| sf.code == 'e' }
    
    field_100.subfields.each do |subfield|
      if subfield.code == 'd'
        subfield.value =  subfield.value.gsub(/[,.]$/, '') # Remove trailing commas or periods
      end
    end
  end

  # Update datafield 856 - remove subfield z and add subfield 3 with "Finding aid"
  def update_datafield_856
    field_856 = @marc_record['856']
    return unless field_856

    field_856.subfields.delete_if { |sf| sf.code == 'z' }
    subfield_3 = field_856.subfields.find { |sf| sf.code == '3' }
    
    if subfield_3
      subfield_3.value = 'Finding aid'
    else
      field_856.append(MARC::Subfield.new('3', 'Finding aid'))
    end
  end

  # Add 965 field
  def add_965noexportAUTH
    field_965 = MARC::DataField.new('965', ' ', ' ', ['a', '965noexportAUTH'])
    @marc_record.append(field_965)
  end

  # Processes corpname punctuation in 110 and 610 datafields
  def corpname_punctuation
    # TODO
  end

  def save_to_xml(output_path)
    writer = MARC::XMLWriter.new(output_path)
    writer.write(@marc_record)
    writer.close
    puts "Saved processed record to #{output_path}"
  end
end