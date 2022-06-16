require 'spec_helper'

module VCAP::CloudController::Presenters::V3::AppManifestPresenters
  RSpec.describe ProcessPropertiesPresenter do
    describe 'command' do
      let(:app) { VCAP::CloudController::AppModel.make }

      context 'when a process does not have a user-specified command' do
        before do
          VCAP::CloudController::ProcessModelFactory.make(
            app: app,
          )
        end

        it 'should not include "command" in the output' do
          expect(subject.to_hash(app: app, service_bindings: nil, routes: nil)[:processes].first).
            not_to have_key('command')
        end
      end

      context 'when a process does have a user-specified command' do
        before do
          VCAP::CloudController::ProcessModelFactory.make(
            app: app,
            command: 'Do it now!'
          )
        end

        it 'should include the command in the output' do
          expect(subject.to_hash(app: app, service_bindings: nil, routes: nil)[:processes].first['command']).
            to eq('Do it now!')
        end
      end
    end

    describe '#process_hash' do
      let(:process) { VCAP::CloudController::ProcessModel.make }

      it 'renders a compact hash of the process' do
        hash = subject.process_hash(process)
        expect(hash).to eq({
          'type' => 'web',
          'instances' => 1,
          'memory' => '1024M',
          'disk_quota' => '1024M',
          'log_quota' => '1MBs',
          'health-check-type' => 'port',
        })
      end
    end

    describe '#add_units_log_quota' do
      context 'log_quota is -1 (unlimited)' do
        it 'returns unlimited' do
          expect(subject.add_units_log_quota(-1)).to eq('unlimited')
        end
      end

      it 'selects the best unit possible' do
        expect(subject.add_units_log_quota(256)).to eq('256Bs')
        expect(subject.add_units_log_quota(2048)).to eq('2KBs')
        expect(subject.add_units_log_quota(4_194_304)).to eq('4MBs')
        expect(subject.add_units_log_quota(6_442_450_944)).to eq('6GBs')
      end
    end
  end
end
