require 'spec_helper'
require 'tasks/rake_config'
require 'database/was_running_backfill'

RSpec.describe 'db.rake', type: :migration do
  let(:db_migrator) { instance_double(DBMigrator) }

  describe ':migrate' do
    let(:stdout_sink_enabled) { true }
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

    before do
      TestConfig.override(**logging_config)
      allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
      allow(DBMigrator).to receive(:from_config).and_return(db_migrator)
      allow(db_migrator).to receive(:apply_migrations)
    end

    after do
      Steno.config.sinks.delete_if { |sink| sink.instance_variable_get(:@io_obj) == $stdout }
    end

    it 'logs to configured sinks + STDOUT' do
      Rake::Task['db:migrate'].execute

      # From test config:
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::IO).and(satisfy { |sink| sink.instance_variable_get(:@io_obj).is_a?(File) }))

      # From db.rake:
      expect(Steno.config.sinks).to include(an_instance_of(Steno::Sink::IO).and(satisfy { |sink| sink.instance_variable_get(:@io_obj) == $stdout }))
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

  describe ':was_running_backfill' do
    let(:db) { Sequel::Model.db }

    before do
      TestConfig.override(logging: { level: 'debug2', file: '/tmp/cloud_controller.log', anonymize_ips: false, format: { timestamp: 'rfc3339' } })
      allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
      allow(VCAP::CloudController::DB).to receive(:connect).and_return(db)
    end

    after do
      Steno.config.sinks.delete_if { |sink| sink.instance_variable_get(:@io_obj) == $stdout }
    end

    def execute_task(batch_size_arg=nil)
      args = batch_size_arg ? Rake::TaskArguments.new([:batch_size], [batch_size_arg]) : Rake::TaskArguments.new([], [])
      Rake::Task['db:was_running_backfill'].execute(args)
    end

    it 'seeds apps, tasks, then services under the fail-fast advisory lock' do
      calls = []
      allow(VCAP::WasRunningBackfill).to receive(:with_advisory_lock).with(db).and_wrap_original do |original, *args, &block|
        calls << :lock
        original.call(*args, &block)
      end
      allow(VCAP::WasRunningBackfill).to receive(:seed_app_usage_events).with(db, anything, batch_size: 1000) { calls << :apps }
      allow(VCAP::WasRunningBackfill).to receive(:seed_task_usage_events).with(db, anything, batch_size: 1000) { calls << :tasks }
      allow(VCAP::WasRunningBackfill).to receive(:seed_service_usage_events).with(db, anything, batch_size: 1000) { calls << :services }

      execute_task

      # Tasks are seeded before services so that the task baselines -- which
      # task stop events depend on -- are on record as early as possible.
      expect(calls).to eq(%i[lock apps tasks services])
    end

    it 'passes a custom batch size through to every seeding step' do
      allow(VCAP::WasRunningBackfill).to receive(:with_advisory_lock).and_yield
      %i[seed_app_usage_events seed_task_usage_events seed_service_usage_events].each do |seed|
        allow(VCAP::WasRunningBackfill).to receive(seed)
      end

      execute_task('500')

      %i[seed_app_usage_events seed_task_usage_events seed_service_usage_events].each do |seed|
        expect(VCAP::WasRunningBackfill).to have_received(seed).with(db, anything, batch_size: 500)
      end
    end

    it 'rejects a non-numeric batch size instead of silently seeding nothing' do
      allow(VCAP::WasRunningBackfill).to receive(:with_advisory_lock)

      expect { execute_task('abc') }.to raise_error(ArgumentError, /invalid value for Integer/)
      expect(VCAP::WasRunningBackfill).not_to have_received(:with_advisory_lock)
    end

    it 'rejects a batch size of 0 instead of silently seeding nothing' do
      expect { execute_task('0') }.to raise_error(ArgumentError, /batch_size/)
    end
  end
end
