require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe 'UserResetInterval mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::UserResetInterval }.new
      end
      let(:user_guid) { 'user_guid' }
      let(:reset_interval_in_minutes) { 60 }
      let(:user_guid_offset) { 592.seconds }

      it 'produces the expected XXH64 hash' do
        expect(Digest::XXH64.idigest(user_guid)).to eq(16_213_529_883_637_274_992)
      end

      context "time is set to beginning of hour + the user's offset" do
        before { Timecop.freeze Time.now.beginning_of_hour + user_guid_offset }
        after { Timecop.return }

        it 'returns expires_in that equals the reset interval' do
          expires_in = implementor.next_expires_in(user_guid, reset_interval_in_minutes)
          expect(expires_in).to eq(reset_interval_in_minutes.minutes.to_i)
        end
      end

      context 'time is set to beginning of hour' do
        before { Timecop.freeze Time.now.beginning_of_hour }
        after { Timecop.return }

        it "returns expires_in that equals the user's offset" do
          expires_in = implementor.next_expires_in(user_guid, reset_interval_in_minutes)
          expect(expires_in).to eq(user_guid_offset.to_i)
        end
      end

      it 'returns expires_in values between 0 and the reset interval' do
        1000.times do
          guid = SecureRandom.alphanumeric
          expires_in = implementor.next_expires_in(guid, reset_interval_in_minutes)
          expect(expires_in).to be_between(0, reset_interval_in_minutes.minutes.to_i)
        end
      end
    end
  end
end
