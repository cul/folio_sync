# frozen_string_literal: true

module HyacinthApi
  module Exceptions
    class HyacinthError < StandardError; end

    class UpdateError < HyacinthError; end
    class ApiError < HyacinthError; end
    class ParseError < HyacinthError; end
  end
end
