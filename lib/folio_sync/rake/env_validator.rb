# frozen_string_literal: true

class FolioSync::Rake::EnvValidator
  def self.validate!(required_vars, usage_message)
    missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].strip.empty? }
    return if missing_vars.empty?

    puts "Error: Missing required environment variables: #{missing_vars.join(', ')}"
    puts "Usage: #{usage_message}"
    exit 1
  end
end
