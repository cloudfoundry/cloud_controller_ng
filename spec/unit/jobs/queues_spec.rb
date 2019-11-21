require 'lightweight_spec_helper'
require 'support/bootstrap/test_config'
require 'jobs/queues'

module VCAP::CloudController
  module Jobs
    RSpec.describe Queues do
      describe '#local(config)' do
        before do
          StubConfig.prepare(
            self,
            {
              name: 'configured-name',
              index: '42'
            }
          )
        end

        it 'returns a local job queue appropriate to passed config' do
          expect(Queues.local(TestConfig.config)).to eq('cc-configured-name-42')
        end
      end

      describe '#generic' do
        it 'returns a generic job queue name' do
          expect(Queues.generic).to eq('cc-generic')
        end
      end
    end
  end
end
