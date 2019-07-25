require 'spec_helper'

module VCAP
  RSpec.describe Loggregator do
    describe 'when no emitter is set' do
      before { Loggregator.emitter = nil }

      it 'does not emit errors' do
        expect_any_instance_of(LoggregatorEmitter::Emitter).not_to receive(:emit_error)
        Loggregator.emit_error('app_id', 'error message')
      end

      it 'does not emit' do
        expect_any_instance_of(LoggregatorEmitter::Emitter).not_to receive(:emit)
        Loggregator.emit('app_id', 'log message')
      end
    end

    describe 'when the emitter is set' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:app) { VCAP::CloudController::AppModel.make(space: space) }

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
          emitter = LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1)
          expect(emitter).to receive(:emit_error).with(app.guid, 'error message', expected_tags)
          Loggregator.emitter = emitter
          Loggregator.emit_error(app.guid, 'error message')
        end

        it 'emits to the loggregator' do
          emitter = LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1)
          expect(emitter).to receive(:emit).with(app.guid, 'log message', expected_tags)
          Loggregator.emitter = emitter
          Loggregator.emit(app.guid, 'log message')
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
          emitter = LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1)
          expect(emitter).to receive(:emit_error).with(app.guid, 'error message', expected_tags)
          Loggregator.emitter = emitter
          Loggregator.emit_error(app.guid, 'error message')
        end

        it 'emits to the loggregator' do
          emitter = LoggregatorEmitter::Emitter.new('127.0.0.1:1234', 'cloud_controller', 'API', 1)
          expect(emitter).to receive(:emit).with(app.guid, 'log message', expected_tags)
          Loggregator.emitter = emitter
          Loggregator.emit(app.guid, 'log message')
        end
      end
    end
  end
end
