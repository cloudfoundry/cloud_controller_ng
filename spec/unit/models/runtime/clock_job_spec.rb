require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ClockJob, type: :model do
    it 'must have a unique name' do
      ClockJob.create name: 'Greg'
      expect {
        ClockJob.create name: 'Greg'
      }.to raise_error Sequel::UniqueConstraintViolation
    end
  end
end
