require 'rails_helper'
require_relative '../lib/folio_processor/folio_synchronizer'

RSpec.describe FOLIOSynchronizer do
  let(:aspace_client) { instance_double("ArchivesSpace::Client", login: aspace_client) }
  let(:logger) { instance_double("Logger", info: nil, error: nil) }
  let(:synchronizer) { FOLIOSynchronizer.new }
end