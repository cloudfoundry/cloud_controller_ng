require 'spec_helper'
require 'tasks/rake_config'
require 'cloud_controller/execution_context'

module VCAP::CloudController
  RSpec.describe ExecutionContext do
    context 'ExecutionInfo' do
      let(:exec_info) { ExecutionContext::CC_WORKER }

      it 'has correct attributes' do
        expect(exec_info.process_type).to eq('cc-worker')
        expect(exec_info.capi_job_name).to eq('cloud_controller_worker')
        expect(exec_info.rake_context).to eq(:worker)
      end

      describe '#set_process_type_env' do
        it 'sets the PROCESS_TYPE environment variable' do
          expect(ENV).to receive(:[]=).with('PROCESS_TYPE', 'cc-worker')
          exec_info.set_process_type_env
        end
      end

      describe '#set_rake_context' do
        context 'when RakeConfig is defined' do
          before { allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance) }

          it 'sets the RakeConfig context' do
            exec_info.set_rake_context
            expect(RakeConfig.context).to eq(:worker)
          end
        end

        context 'when RakeConfig is not defined' do
          it 'raises an error' do
            hide_const('RakeConfig')
            expect { exec_info.set_rake_context }.to raise_error('RakeConfig is not defined or rake_context argument is nil')
          end
        end

        context 'when rake_context is nil' do
          let(:exec_info) { ExecutionContext::API_PUMA_MAIN }

          it 'raises an error' do
            expect { exec_info.set_rake_context }.to raise_error('RakeConfig is not defined or rake_context argument is nil')
          end
        end
      end
    end

    context 'from process type env' do
      it 'returns the CC_WORKER execution context' do
        allow(ENV).to receive(:fetch).with('PROCESS_TYPE', nil).and_return('cc-worker')
        expect(ExecutionContext.from_process_type_env).to eq(ExecutionContext::CC_WORKER)
      end

      it 'returns nil for unknown process type' do
        allow(ENV).to receive(:fetch).with('PROCESS_TYPE', nil).and_return('unknown-process')
        allow(ENV).to receive(:fetch).with('CC_TEST', nil).and_return(nil)
        expect(ExecutionContext.from_process_type_env).to be_nil
      end

      it 'returns API_PUMA_MAIN when PROCESS_TYPE is not set in unit test context' do
        allow(ENV).to receive(:fetch).with('PROCESS_TYPE', nil).and_return(nil)
        allow(ENV).to receive(:fetch).with('CC_TEST', nil).and_call_original # set by spec_helper
        expect(ExecutionContext.from_process_type_env).to eq(ExecutionContext::API_PUMA_MAIN)
      end
    end
  end
end
