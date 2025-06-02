# frozen_string_literal: true

RSpec.describe FolioSync::Rake::EnvValidator do
  describe '.validate!' do
    let(:usage_message) { 'Usage: bundle exec rake task_name ENV_VAR=value' }

    context 'when all required environment variables are present' do
      before do
        ENV['VAR1'] = 'value1'
        ENV['VAR2'] = 'value2'
      end

      it 'does not raise an error or exit' do
        expect { described_class.validate!(%w[VAR1 VAR2], usage_message) }.not_to raise_error
      end
    end

    context 'when some required environment variables are missing' do
      before do
        ENV['VAR1'] = nil
        ENV['VAR2'] = 'value2'
      end

      it 'prints an error message and exits' do
        expect {
          described_class.validate!(%w[VAR1 VAR2], usage_message)
        }.to raise_error(SystemExit).and output(
          "Error: Missing required environment variables: VAR1\nUsage: #{usage_message}\n"
        ).to_stdout
      end
    end

    context 'when all required environment variables are empty' do
      before do
        ENV['VAR1'] = ''
        ENV['VAR2'] = '   '
      end

      it 'prints an error message and exits' do
        expect {
          described_class.validate!(%w[VAR1 VAR2], usage_message)
        }.to raise_error(SystemExit).and output(
          "Error: Missing required environment variables: VAR1, VAR2\nUsage: #{usage_message}\n"
        ).to_stdout
      end
    end
  end
end
