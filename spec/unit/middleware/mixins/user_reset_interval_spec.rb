require 'spec_helper'
require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    RSpec.describe 'UserResetInterval mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::UserResetInterval }.new
      end
      let(:reset_interval_in_minutes) { 60 }
      let(:user_guid) { 'user_guid' }
      let(:user_guid_offset) { 1170.seconds }

      before(:each) { Timecop.freeze Time.now.utc.beginning_of_hour }
      after(:each) { Timecop.return }

      it 'returns the next time interval including offset' do
        next_interval = implementor.next_reset_interval(user_guid, reset_interval_in_minutes)
        expect(next_interval).to eq(Time.now.utc.beginning_of_hour + user_guid_offset)
      end

      it 'returns a new interval that is reset_interval_in_minutes later when current time is after offset' do
        Timecop.freeze(Time.now.utc.beginning_of_hour + user_guid_offset + 1.minutes) do
          next_interval = implementor.next_reset_interval(user_guid, reset_interval_in_minutes)
          expect(next_interval).to eq(Time.now.utc.beginning_of_hour + user_guid_offset + reset_interval_in_minutes.minutes)
        end
      end

      it 'returns offsets between 0 and 1 times the reset_interval' do
        1000.times do
          guid = SecureRandom.alphanumeric
          next_interval = implementor.next_reset_interval(guid, reset_interval_in_minutes)
          expect(next_interval).to be_within(reset_interval_in_minutes.minutes).of(Time.now.utc.beginning_of_hour)
        end
      end
    end
  end
end
