require 'spec_helper'

RSpec.describe HealthCheckPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make }

  subject(:validator) { HealthCheckPolicy.new(app, health_check_timeout) }
  let(:max_health_check_timeout) { 512 }

  describe 'health_check_timeout' do
    before do
      TestConfig.override({ maximum_health_check_timeout: max_health_check_timeout })
    end

    context 'when a health_check_timeout exceeds the maximum' do
      let(:health_check_timeout) { 1024 }

      it 'registers error' do
        error_msg = "Maximum exceeded: max #{max_health_check_timeout}s"
        expect(validator).to validate_with_error(app, :health_check_timeout, error_msg)
      end
    end

    context 'when a health_check_timeout is less than zero' do
      let(:health_check_timeout) { -10 }

      it 'registers error' do
        expect(validator).to validate_with_error(app, :health_check_timeout, :less_than_zero)
      end
    end

    context 'when a health_check_timeout is greater than zero' do
      let(:health_check_timeout) { 10 }

      it 'does not register error' do
        expect(validator).to validate_without_error(app)
      end
    end
  end
end
