require 'spec_helper'
require 'cloud_controller/copilot/scheduler'

module VCAP::CloudController
  RSpec.describe Copilot::Scheduler do
    before do
      TestConfig.context = :route_syncer
      TestConfig.override(
        copilot: {
          enabled: true,
          sync_frequency_in_seconds: 42,
        }
      )
    end

    describe '#start' do
      it 'loops, calls sync, and sleeps for a given period' do
        expect(Copilot::Scheduler).to receive(:loop).and_yield
        expect(Copilot::Sync).to receive(:sync)
        expect(Copilot::Scheduler).to receive(:sleep).with(42)

        Copilot::Scheduler.start
      end
    end
  end
end
