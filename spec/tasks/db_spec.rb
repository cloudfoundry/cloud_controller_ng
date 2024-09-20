require 'spec_helper'
require 'tasks/rake_config'

RSpec.describe 'db.rake', type: :migration do
  let(:db_migrator) { instance_double(DBMigrator) }

  describe ':migrate' do
    let(:stdout_sink_enabled) { true }
    let(:logging_config) do
      {
        logging: {
          stdout_sink_enabled: stdout_sink_enabled,
          level: 'debug2',
          syslog: 'vcap.example',
          file: '/tmp/cloud_controller.log',
          anonymize_ips: false,
          format: { timestamp: 'rfc3339' }
        }
      }
    end

    before do
      TestConfig.override(**logging_config)
      allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
      allow(DBMigrator).to receive(:from_config).and_return(db_migrator)
      allow(db_migrator).to receive(:apply_migrations)
    end

    after do
      Steno.config.sinks.delete_if { |sink| sink.instance_variable_get(:@io) == $stdout }
    end

    it 'logs to configured sinks + STDOUT' do
      Rake::Task['db:migrate'].execute

      # From test config:
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::Syslog))
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::IO).and(satisfy { |sink| sink.instance_variable_get(:@io).is_a?(File) }))

      # From db.rake:
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::IO).and(satisfy { |sink| sink.instance_variable_get(:@io) == $stdout }))
    end

    describe 'steno sink' do
      let(:logging_config) do
        {
          logging: {
            stdout_sink_enabled: stdout_sink_enabled,
            level: 'debug2',
            file: '/tmp/cloud_controller.log',
            anonymize_ips: false,
            format: { timestamp: 'rfc3339' }
          }
        }
      end

      context 'when `stdout_sink_enabled` is `true`' do
        it 'configures steno logger with stdout sink' do
          Rake::Task['db:migrate'].execute
          expect(Steno.logger('cc.db.migrations').instance_variable_get(:@sinks).length).to eq(2)
        end
      end

      context 'when `stdout_sink_enabled` is not set' do
        let(:logging_config) do
          {
            logging: {
              level: 'debug2',
              file: '/tmp/cloud_controller.log',
              anonymize_ips: false,
              format: { timestamp: 'rfc3339' }
            }
          }
        end

        it 'configures steno logger with stdout sink' do
          Rake::Task['db:migrate'].invoke

          expect(Steno.logger('cc.db.migrations').instance_variable_get(:@sinks).length).to eq(2)
        end
      end

      context 'when `stdout_sink_enabled` is `false`' do
        let(:stdout_sink_enabled) { false }

        it 'configures steno logger without stdout sink' do
          Rake::Task['db:migrate'].execute
          expect(Steno.logger('cc.db.migrations').instance_variable_get(:@sinks).length).to eq(1)
        end
      end
    end
  end
end
