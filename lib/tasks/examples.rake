# frozen_string_literal: false

namespace :folio_sync do
  namespace :examples do
    def create_new_marc_record
      marc_record = MARC::Record.new_from_marc("04181cpc a2200589 u 4500005001700000008004100017035003300058035002100091035002500112035001700137035001200154040006500166041000800231049001100239099001200250100008000262300004200342351006400384506019600448506004100644520040800685524015701093540024001250541013001490545036801620555004801988583004602036584013702082600007402219610007602293610003602369610003802405610003402443610003002477610005802507610007402565630004902639650007102688650003602759650007602795650008102871650003202952650006102984650006803045650007203113656007203185656006903257852008603326856007803412965002003490245008103510\u001E20250517052109.4\u001E890814i19251977xxu                 eng d\u001E  \u001Fa(NNC)CULASPC:voyager:4079151\u001E  \u001Fa(OCoLC)428644059\u001E  \u001Fa(CStRLIN)NYCR89-A644\u001E  \u001Fa(NNC)4079151\u001E  \u001Fa4079151\u001E  \u001FaNNC-RB\u001Fbeng\u001FcNNC-RB\u001FeDescribing Archives: A Content Standard\u001E  \u001Faeng\u001E  \u001FaNNC-RB\u001E  \u001Fa4079151\u001E1 \u001FaNelson, Benjamin,\u001Fd1911-1977\u001F0http://id.loc.gov/authorities/names/n79073669\u001E  \u001Fa106\u001Fflinear feet (224 document boxes)\u001E  \u001FaSelected materials cataloged remainder listed and arranged.\u001E1 \u001FaThis collection is located off-site. You will need to request this material at least three business days in advance to use the collection in the Rare Book and Manuscript Library reading room.\u001E1 \u001FaThis collection has no restrictions.\u001E2 \u001FaProfessional and personal correspondence, manuscripts and notes for his many publications in the social sciences and Renaissance studies, drafts and notes for his THE IDEA OF USURY and writings about Max Weber, other papers collected during his teaching career, and materials for the many professional conferences which he attended and for the academic associations and societies in which he was active.\u001E  \u001FaIdentification of specific item; Date (if known); Benjamin Nelson papers; Box and Folder; Rare Book and Manuscript Library, Columbia University Library.\u001E  \u001FaReproductions may be made for research purposes. The RBML maintains ownership of the physical material only. Copyright remains with the creator and his/her heirs. The responsibility to secure copyright permission rests with the patron.\u001E1 \u001FaSource of acquisition--Nelson, Marie Coleman. Method of acquisition--Gift; Date of acquisition--1978. Accession number--M-78.\u001E  \u001FaHistorian, sociologist. Nelson taught at City College of New York, the University of Chicago, the University of Minnesota, Columbia University, Hofstra College, S.U.N.Y. Stony Brook, and The New School for Social Research. He also edited special issues of PSYCHOANALYSIS AND THE PSYCHOANALYTIC REVIEW and acted as an advisor for Harper & Row and other publishers.\u001E0 \u001FaFinding aid in repository;box level control\u001E1 \u001FaCataloged Christina Hilton Fenn 08/--/89.\u001E  \u001FaMaterials may have been added to the collection since this finding aid was prepared. Contact rbml@columbia.edu for more information.\u001E10\u001FaWeber, Max,\u001Fd1864-1920\u001F0http://id.loc.gov/authorities/names/n79043351\u001E20\u001FaHarper & Row, Publishers\u001F0http://id.loc.gov/authorities/names/n80051838\u001E20\u001FaUniversity of Chicago\u001FxFaculty.\u001E20\u001FaUniversity of Minnesota\u001FxFaculty.\u001E20\u001FaColumbia University\u001FxFaculty.\u001E20\u001FaHofstra College\u001FxFaculty.\u001E20\u001FaState University of New York at Stony Brook\u001FxFaculty.\u001E20\u001FaNew School for Social Research (New York, N.Y. : 1919-1997)\u001FxFaculty.\u001E00\u001FaPsychoanalysis and the psychoanalytic review\u001E 0\u001FaSocial sciences\u001F0http://id.loc.gov/authorities/subjects/sh85124003\u001E 0\u001FaRenaissance\u001FxStudy and teaching\u001E 0\u001FaScholarly publishing\u001F0http://id.loc.gov/authorities/subjects/sh85118235\u001E 0\u001FaPublishers and publishing\u001F0http://id.loc.gov/authorities/subjects/sh85108871\u001E 0\u001FaPsychoanalysis\u001FvPeriodicals\u001E 0\u001FaUsury\u001F0http://id.loc.gov/authorities/subjects/sh85141574\u001E 0\u001FaSociologists\u001F0http://id.loc.gov/authorities/subjects/sh85124199\u001E 0\u001FaCollege teachers\u001F0http://id.loc.gov/authorities/subjects/sh85028378\u001E 7\u001FaHistorians\u001F2lcsh\u001F0http://id.loc.gov/authorities/subjects/sh85061091\u001E 7\u001FaEditors\u001F2lcsh\u001F0http://id.loc.gov/authorities/subjects/sh85040976\u001E  \u001FaColumbia University Libraries\u001FbRare Book and Manuscript Library\u001Fc4079151\u001FjMS#1485\u001E42\u001Fuhttp://findingaids.cul.columbia.edu/ead/nnc-rb/ldpd_4079151/\u001F3Finding aid\u001E  \u001Fa965noexportAUTH\u001E10\u001Fa!!! This is the MARC record title for this record: 2025-05-29T23:19:42-04:00\u001E\u001D") # rubocop:disable Layout/LineLength
      # Delete 001 so that this is recognized by FOLIO as a new MARC record
      marc_record.fields.delete_if { |f| %w[001].include? f.tag }

      # Temporary, for testing: Clear the current title and set it to something with a date and
      # time in it so updates are more noticeable.
      marc_record.fields.delete_if { |f| f.tag == '245' }
      marc_record.append(
        MARC::DataField.new(
          '245', '1', '0',
          ['a', "!!! This is the MARC record title for this record: #{Time.now.iso8601}"]
        )
      )
      marc_record
    end

    task folio_update_and_create_example: :environment do
      # These are existing FOLIO records that we want to update
      records_to_update = [
        { hrid: '2157842', aspace_uri: '/repositories/2/resources/5300',
          aspace_marc_download_path: '/repositories/2/resources/marc21/5300.xml' },
        { hrid: '4077533', aspace_uri: '/repositories/2/resources/1368',
          aspace_marc_download_path: '/repositories/2/resources/marc21/1368.xml' }
      ]

      # This is the number of new FOLIO records that we want to create.
      # For these records, we'll pretend that there are corresponding Aspace records.
      number_of_new_records_to_create = 2

      # Pre-download Aspace MARC records
      cul_aspace_client = FolioSync::ArchivesSpace::Client.new('cul')
      records_to_update.each do |record_to_update|
        hrid = record_to_update[:hrid]
        aspace_marc_download_path = record_to_update[:aspace_marc_download_path]

        download_path = File.join(
          Rails.configuration.folio_sync[:aspace_to_folio][:marc_download_base_directory], 'cul', "#{hrid}.xml"
        )

        # For this example rake task, we'll only re-download the file when needed (to speed up testing)
        if File.exist?(download_path)
          puts "File already exists at #{download_path} (skipping re-download)"
          next
        end

        # Write downloaded file
        File.binwrite(download_path, cul_aspace_client.get(aspace_marc_download_path).body)
      end

      # Create a Folio::Client::JobExecution object
      #
      # The id below is associted with the 'ArchivesSpace to FOLIO - Batch create or update MARC records' job profile.
      job_profile_uuid = '3fe97378-297c-40d9-9b42-232510afc58f'
      data_type = 'MARC' # We always send MARC
      # The FOLIO Job Exeuction API requires that we say, in advance of sending any records, how many total records we
      # plan to send.  This number must match the actual number of records that we end up adding to the Job Execution.
      total_number_of_records_that_we_plan_to_submit = records_to_update.length + number_of_new_records_to_create
      # When adding lots of records to a Job Execution, we don't send them all in one batch.  We break up the whole
      # set into smaller batches.  The number below indicates that batch size.
      # Scenario: Let's say that we want to run a Job Execution with 199 total records and a batch size of 50.
      # The entire job will process 199 records once we've added all of the records, but behind the scenes we will
      # actually be submitting the records in four batches: 50, 50, 50, and 49.  We will only start the job after all
      # 199 records have been submitted.
      # Even though you need to specify a batch_size, the actual batching logic is taken care of automatically
      # by the Folio::Client::JobExecution class.  The batch_size just affects performance.  It's probably more
      # efficient to have larger batches, since that means fewer http requests behind the scenes.  But we probably
      # also don't want to make batches too large, since it will result in a request with a larger payload and that
      # might be more likely to time out.  We'll have to do some testing to figure out the ideal batch size.
      batch_size = 50
      job_execution = FolioSync::Folio::Client.instance.create_job_execution(
        job_profile_uuid, data_type, total_number_of_records_that_we_plan_to_submit, batch_size
      )

      # Add some FOLIO record updates to the Job Execution
      records_to_update.each do |record_to_update|
        hrid = record_to_update[:hrid]
        aspace_uri = record_to_update[:aspace_uri]

        enhanced_marc_record = FolioSync::ArchivesSpaceToFolio::MarcRecordEnhancer.new(
          hrid, 'cul'
        ).enhance_marc_record!
        job_execution.add_record(enhanced_marc_record, { hrid: hrid, aspace_uri: aspace_uri })
      end

      # Now we'll create some new FOLIO records as part of this Job Execution
      # When you want to create a new FOLIO record, you need to submit a MARC record without an 001 field value.
      # The Job Execution will interpret that as a CREATE operation (and not an UPDATE).
      number_of_new_records_to_create.times do |i|
        new_marc_record = create_new_marc_record
        # Let's pretend that this new marc record (without an 001 value) was from an
        # Aspace record with resource uri: /repositories/990/resource/#{i}
        # We'll add that resource uri to a custom metadata field called aspace_uri so that we can link this data up
        # with the Job Execution results later on.
        new_marc_record_aspace_uri = "/repositories/999/resource/#{i}"
        job_execution.add_record(new_marc_record, { aspace_uri: new_marc_record_aspace_uri })
      end

      # After we're done adding all records, start the job execution
      job_execution.start

      # And wait for the job execution to complete.  The more records we submit, the longer this will take.
      # TODO: We may eventually want to add a timeout parameter to the `wait_until_complete` method if things
      # take a while.  We can add that later though, if necessary.
      puts 'Waiting for job to complete...'

      # The returned object below is a Folio::Client::JobExecutionSummary
      job_execution_summary = job_execution.wait_until_complete

      puts 'Result summary:'
      puts "#{job_execution_summary.records_processed} records processed"
      job_execution_summary.each_result do |raw_result, custom_metadata, instance_action_status, hrid_list|
        puts '----------------------------------------'
        puts "instance_action_status: #{instance_action_status}"
        puts "hrid_list: #{hrid_list.inspect}"
        puts "custom_metadata: #{custom_metadata}"
        puts "result: #{raw_result}"
      end
    end
  end
end
