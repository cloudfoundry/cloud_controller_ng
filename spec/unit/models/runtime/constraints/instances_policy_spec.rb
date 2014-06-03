require "spec_helper"

describe InstancesPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }

  subject(:validator) { InstancesPolicy.new(app)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }
  end

  describe "instances" do
    it "registers an error if requested instances is negative" do
      allow(app).to receive(:requested_instances).and_return(-1)
      expect(validator).to validate_with_error(app, :less_than_one)
    end

    it "registers an error if requested instances is zero" do
      allow(app).to receive(:requested_instances).and_return(0)
      expect(validator).to validate_with_error(app, :less_than_one)
    end

    it "does not register error if the requested instances is 1" do
      allow(app).to receive(:requested_instances).and_return(1)
      expect(validator).to validate_without_error(app)
    end

    it "does not register error if the requested instances is greater than 1" do
      allow(app).to receive(:requested_instances).and_return(2)
      expect(validator).to validate_without_error(app)
    end
  end
end
