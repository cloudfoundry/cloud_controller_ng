require 'spec_helper'
require 'cloud_controller/job/job_priority_overwriter'

module VCAP::CloudController
  RSpec.describe JobPriorityOverwriter do
    let(:config) do
      Config.new({
                   jobs: {
                     priorities: {
                       "resource1.create": -20,
                       "resource2.delete": 10
                     },
                   }
                 })
    end

    context 'when a job is specified in the config' do
      it 'returns the job priority from the config' do
        expect(JobPriorityOverwriter.new(config).get(:"resource1.create")).to eq(-20)
        expect(JobPriorityOverwriter.new(config).get(:"resource2.delete")).to eq(10)
      end
    end

    context 'when a job is NOT specified in the config' do
      it 'returns nil' do
        expect(JobPriorityOverwriter.new(config).get(:"res1.bommel")).to eq(nil)
      end
    end

    context 'when the job_name is nil' do
      it 'returns nil' do
        expect(JobPriorityOverwriter.new(config).get(nil)).to eq(nil)
      end
    end

    context 'when the config is empty' do
      it 'returns nil' do
        expect(JobPriorityOverwriter.new(Config.new({})).get(:"res1.bommel")).to eq(nil)
      end
    end
  end
end
