require 'spec_helper'
require 'support/bootstrap/test_config'
require 'jobs/queues'

module VCAP::CloudController
  module Jobs
    RSpec.describe Queues do
      describe '#local(config)' do
        context 'when explicitly configuring queue name' do
          before do
            TestConfig.override(
              name: 'configured-name',
              index: '42'
            )
          end

          it 'returns a local job queue appropriate to passed config' do
            expect(Queues.local(TestConfig.config_instance)).to eq('cc-configured-name-42')
          end
        end

        context 'when NOT configuring queue name' do
          before do
            ENV['HOSTNAME'] = 'poop'
            TestConfig.override(
              name: ''
            )
          end

          it 'returns a local job queue using the hostname of the local worker as the name' do
            expect(Queues.local(TestConfig.config_instance)).to eq('cc-poop')
          end
        end
      end

      describe '#generic' do
        it 'returns a generic job queue name' do
          expect(Queues.generic).to eq('cc-generic')
        end
      end

      describe '.local?' do
        it 'returns true for a local queue name' do
          expect(Queues.local?('cc-some-host')).to be(true)
        end

        it 'returns true for a local queue name with index' do
          expect(Queues.local?('cc-cloud_controller_ng-0')).to be(true)
        end

        it 'returns false for cc-generic' do
          expect(Queues.local?('cc-generic')).to be(false)
        end

        it 'returns false for named clock queues' do
          expect(Queues.local?('app_usage_events')).to be(false)
          expect(Queues.local?('pending_builds')).to be(false)
        end
      end
    end
  end
end
