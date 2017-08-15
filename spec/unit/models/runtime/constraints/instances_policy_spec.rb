require 'spec_helper'

RSpec.describe InstancesPolicy do
  let(:process) { VCAP::CloudController::ProcessModelFactory.make }

  subject(:validator) { InstancesPolicy.new(process) }

  describe 'instances' do
    it 'registers an error if requested instances is negative' do
      process.instances = -1
      expect(validator).to validate_with_error(process, :instances, :less_than_zero)
    end

    it 'does not register error if the requested instances is 0' do
      process.instances = 0
      expect(validator).to validate_without_error(process)
    end

    it 'does not register error if the requested instances is greater than 0' do
      process.instances = 1
      expect(validator).to validate_without_error(process)
    end
  end
end
