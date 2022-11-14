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

      it 'returns the next expires in including offset' do
        expires_in = implementor.next_expires_in(user_guid, reset_interval_in_minutes)
        expect(expires_in).to eq(user_guid_offset)
      end

      it 'returns a new expires in that is reset_interval_in_minutes later when current time is after offset' do
        Timecop.freeze(Time.now.utc.beginning_of_hour + user_guid_offset + 1.minute) do
          expires_in = implementor.next_expires_in(user_guid, reset_interval_in_minutes)
          expect(expires_in).to eq(reset_interval_in_minutes.minutes - 1.minute)
        end
      end

      it 'returns offsets between 0 and the reset_interval in seconds' do
        1000.times do
          guid = SecureRandom.alphanumeric
          expires_in = implementor.next_expires_in(guid, reset_interval_in_minutes)
          expect(expires_in).to be_between(0, reset_interval_in_minutes.minutes)
        end
      end
    end
  end
end
