require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ClockJob, type: :model do
    it 'must have a unique name' do
      ClockJob.create name: 'Greg'
      expect do
        ClockJob.create name: 'Greg'
      end.to raise_error Sequel::UniqueConstraintViolation
    end
  end
end
