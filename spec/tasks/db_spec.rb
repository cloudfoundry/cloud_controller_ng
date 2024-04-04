require 'spec_helper'
require 'tasks/rake_config'

RSpec.describe 'db.rake' do
  let(:db_migrator) { instance_double(DBMigrator) }

  describe ':migrate' do
    before do
      allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
      allow(DBMigrator).to receive(:from_config).and_return(db_migrator)
      allow(db_migrator).to receive(:apply_migrations)

      Application.load_tasks
    end

    it 'logs to configured sinks + STDOUT' do
      Rake::Task['db:migrate'].invoke

      expect(db_migrator).to have_received(:apply_migrations)

      # From test config:
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::Syslog))
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::IO).and(satisfy { |sink| sink.instance_variable_get(:@io).is_a?(File) }))

      # From db.rake:
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::IO).and(satisfy { |sink| sink.instance_variable_get(:@io) == $stdout }))
    end
  end
end
