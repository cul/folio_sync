# frozen_string_literal: true

module HyacinthApi
  class Configuration
    DEFAULT_TIMEOUT = 60

    attr_reader :url, :email, :password, :timeout

    def initialize(url:, email:, password:, timeout: DEFAULT_TIMEOUT)
      @url = url
      @email = email
      @password = password
      @timeout = timeout
    end
  end
end
