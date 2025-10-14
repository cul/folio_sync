# frozen_string_literal: true

class HyacinthApiClient
  module Exceptions
    class HyacinthError < StandardError; end

    class UpdateError < HyacinthError; end
    class ApiError < HyacinthError; end
    class ParseError < HyacinthError; end
  end
end
