require "spec_helper"

describe HealthCheckPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make }

  subject(:validator) { HealthCheckPolicy.new(app, health_check_timeout)}

  describe "health_check_timeout" do
    before do
      TestConfig.override({ :maximum_health_check_timeout => 512 })
    end

    context "when a health_check_timeout exceeds the maximum" do
      let(:health_check_timeout) { 1024 }
      
      it "registers error" do
        expect(validator).to validate_with_error(app, :health_check_timeout, :maximum_exceeded)
      end
    end

    context "when a health_check_timeout is less than zero" do
      let(:health_check_timeout) { -10 }

      it "registers error" do
        expect(validator).to validate_with_error(app, :health_check_timeout, :less_than_zero)
      end
    end

    context "when a health_check_timeout is greater than zero" do
      let(:health_check_timeout) { 10 }

      it "does not register error" do
        expect(validator).to validate_without_error(app)
      end
    end
  end
end
