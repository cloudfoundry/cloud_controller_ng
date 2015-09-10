require 'spec_helper'

describe InstancesPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make }

  subject(:validator) { InstancesPolicy.new(app) }

  describe 'instances' do
    it 'registers an error if requested instances is negative' do
      app.instances = -1
      expect(validator).to validate_with_error(app, :instances, :less_than_zero)
    end

    it 'does not register error if the requested instances is 0' do
      app.instances = 0
      expect(validator).to validate_without_error(app)
    end

    it 'does not register error if the requested instances is greater than 0' do
      app.instances = 1
      expect(validator).to validate_without_error(app)
    end
  end
end
