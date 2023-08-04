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
      let(:process) do
        VCAP::CloudController::ProcessModel.make(
          health_check_type: 'http',
          health_check_http_endpoint: '/healthy',
          health_check_invocation_timeout: 10,
          health_check_interval: 5,
          readiness_health_check_type: 'http',
          readiness_health_check_http_endpoint:'/ready',
          readiness_health_check_invocation_timeout: 20,
          readiness_health_check_interval: 7,
          health_check_timeout: 30
        )
      end

      it 'renders a compact hash of the process' do
        hash = subject.process_hash(process)
        expect(hash).to eq({
          'type' => 'web',
          'instances' => 1,
          'memory' => '1024M',
          'disk_quota' => '1024M',
          'log-rate-limit-per-second' => '1M',
          'health-check-type' => 'http',
          'health-check-http-endpoint' => '/healthy',
          'health-check-invocation-timeout' => 10,
          'health-check-interval' => 5,
          'readiness-health-check-type' => 'http',
          'readiness-health-check-http-endpoint' => '/ready',
          'readiness-health-check-invocation-timeout' => 20,
          'readiness-health-check-interval' => 7,
          'timeout' => 30
        })
      end
    end

    describe '#add_units_log_rate_limit' do
      it 'is consistent with other quotas with output' do
        expect(subject.add_units_log_rate_limit(-1)).to eq(-1)
        expect(subject.add_units_log_rate_limit(256)).to eq('256B')
        expect(subject.add_units_log_rate_limit(2_048)).to eq('2K')
        expect(subject.add_units_log_rate_limit(4_194_304)).to eq('4M')
        expect(subject.add_units_log_rate_limit(6_442_450_944)).to eq('6G')
      end
    end
  end
end
