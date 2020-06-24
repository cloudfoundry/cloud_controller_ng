require 'spec_helper'

module VCAP
  RSpec.describe AppLogEmitter do
    let(:logger) { instance_double(::Steno::Logger) }
    before do
      AppLogEmitter.logger = logger
      AppLogEmitter.fluent_emitter = nil
      AppLogEmitter.emitter = nil
    end

    after do
      AppLogEmitter.logger = nil
      AppLogEmitter.fluent_emitter = nil
      AppLogEmitter.emitter = nil
    end

    describe 'when no emitter is set' do
      it 'does not emit errors' do
        expect_any_instance_of(LoggregatorEmitter::Emitter).not_to receive(:emit_error)
        AppLogEmitter.emit_error('app_id', 'error message')
      end

      it 'does not emit' do
        expect_any_instance_of(LoggregatorEmitter::Emitter).not_to receive(:emit)
        AppLogEmitter.emit('app_id', 'log message')
      end
    end

    describe 'when the fluentd client is set' do
      let(:fluent_emitter) { instance_double(FluentEmitter) }
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }
      before do
        AppLogEmitter.fluent_emitter = fluent_emitter
      end

      it 'emits app event logs to the fluent emitter' do
        expect(fluent_emitter).to receive(:emit).with(app.guid, 'log message')

        AppLogEmitter.emit(app.guid, 'log message')
      end

      it 'emits app event logs to the fluent emitter' do
        expect(fluent_emitter).to receive(:emit).with(app.guid, 'error')

        AppLogEmitter.emit_error(app.guid, 'error')
      end

      it 'logs errors on failure' do
        expect(fluent_emitter).to receive(:emit).with(app.guid, 'log message').and_raise(StandardError.new('rekt'))
        expect(logger).to receive(:error)

        AppLogEmitter.emit(app.guid, 'log message')
      end
    end

    describe 'when the loggregator emitter is set' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }
      let(:emitter) { LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1) }
      before {
        AppLogEmitter.emitter = emitter
      }

      context 'when the app exists' do
        let(:expected_tags) do
          {
            app_id: app.guid,
            app_name: app.name,
            space_id: space.guid,
            space_name: space.name,
            organization_id: org.guid,
            organization_name: org.name
          }
        end

        it 'emits errors to the loggregator' do
          expect(emitter).to receive(:emit_error).with(app.guid, 'error message', expected_tags)
          AppLogEmitter.emitter = emitter
          AppLogEmitter.emit_error(app.guid, 'error message')
        end

        it 'emits to the loggregator' do
          expect(emitter).to receive(:emit).with(app.guid, 'log message', expected_tags)
          AppLogEmitter.emitter = emitter
          AppLogEmitter.emit(app.guid, 'log message')
        end
      end

      context 'when the app does not exist' do
        let(:expected_tags) do
          {
            app_id: app.guid,
            app_name: '',
            space_id: '',
            space_name: '',
            organization_id: '',
            organization_name: ''
          }
        end

        before do
          app.delete
        end

        it 'emits errors to the loggregator' do
          expect(emitter).to receive(:emit_error).with(app.guid, 'error message', expected_tags)
          AppLogEmitter.emitter = emitter
          AppLogEmitter.emit_error(app.guid, 'error message')
        end

        it 'emits to the loggregator' do
          expect(emitter).to receive(:emit).with(app.guid, 'log message', expected_tags)
          AppLogEmitter.emitter = emitter
          AppLogEmitter.emit(app.guid, 'log message')
        end
      end
    end
  end
end
