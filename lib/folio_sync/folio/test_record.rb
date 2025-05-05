class FolioSync::Folio::TestRecord
  attr_reader :marc_record, :bibid

  def initialize(bibid)
    @bibid = bibid

    aspace_marc_path = Rails.root.join("tmp/marc_files", "#{bibid}.xml").to_s
    aspace_record = MARC::XMLReader.new(aspace_marc_path, parser: "nokogiri")

    @marc_record = aspace_record.first
  end

  def process_record
    puts "Processing..."
    add_controlfield_001
    add_controlfield_003
    update_datafield_100 
    update_datafield_856
    add_965noexportAUTH
    corpname_punctuation
    
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
        subfield.value =  subfield.value.gsub(/[,.]$/, '')
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
    field_110 = @marc_record['110']
    process_corpname_datafield(field_110) if field_110

    @marc_record.fields.each_by_tag('610') do |field_610|
      process_corpname_datafield(field_610)
    end
  end

  # Processes a corpname datafield (110 or 610) to remove trailing punctuation from subfields a and b.  
  # - If subfield `a` exists but `b` is not present
  #   - Remove punctuation from `a`
  # - If both subfield `a` and `b` exist
  #   - Remove punctuation from `b
  def process_corpname_datafield(field)
    subfields_a = field.subfields.select { |sf| sf.code == 'a' }

    if subfields_a.any?
      subfields_b = field.subfields.select { |sf| sf.code == 'b' }
      if subfields_b.empty?
        subfields_a.each do |subfield|
          subfield.value = subfield.value.gsub(/[,.]$/, '')
        end
      else
        subfields_b.each do |subfield|
          subfield.value = subfield.value.gsub(/[,.]$/, '')
        end
      end
    end
  end

  def save_to_xml(output_path)
    writer = MARC::XMLWriter.new(output_path)
    writer.write(@marc_record)
    writer.close
    puts "Saved processed record to #{output_path}"
  end
end