require "spec_helper"

describe HealthCheckPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }

  subject(:validator) { HealthCheckPolicy.new(app, health_check_timeout)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }
  end

  describe "health_check_timeout" do
    before do
      config_override({ :maximum_health_check_timeout => 512 })
    end

    context "when a health_check_timeout exceeds the maximum" do
      let(:health_check_timeout) { 1024 }
      
      it "registers error" do
        expect(validator).to validate_with_error(app, :maximum_exceeded)
      end
    end

    context "when a health_check_timeout is less than zero" do
      let(:health_check_timeout) { -10 }

      it "registers error" do
        expect(validator).to validate_with_error(app, :less_than_zero)
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
