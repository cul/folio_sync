# frozen_string_literal: true

class FolioSync::Hyacinth::Client < HyacinthApi::Client
  # HyacinthApi will be extracted to a gem in the future
  def self.instance
    @instance ||= self.new(
      HyacinthApi::Configuration.new(
        url: Rails.configuration.hyacinth['url'],
        email: Rails.configuration.hyacinth['email'],
        password: Rails.configuration.hyacinth['password'],
      )
    )
    @instance
  end
end
