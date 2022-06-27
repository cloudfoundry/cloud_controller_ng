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
          'log_rate_limit' => '1048576Bs',
          'health-check-type' => 'port',
        })
      end
    end

    describe '#add_units_log_rate_limit' do
      context 'log_rate_limit is -1 (unlimited)' do
        it 'returns unlimited' do
          expect(subject.add_units_log_rate_limit(-1)).to eq('unlimited')
        end
      end

      it 'is consistant with other quotas with output' do
        expect(subject.add_units_log_rate_limit(256)).to eq('256Bs')
        expect(subject.add_units_log_rate_limit(2_048)).to eq('2048Bs')
        expect(subject.add_units_log_rate_limit(4_194_304)).to eq('4194304Bs')
        expect(subject.add_units_log_rate_limit(6_442_450_944)).to eq('6442450944Bs')
      end
    end
  end
end
