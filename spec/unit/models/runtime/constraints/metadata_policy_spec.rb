require "spec_helper"

describe MetadataPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }

  subject(:validator) { MetadataPolicy.new(app, metadata)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }
  end

  context "when metadata is a hash" do
    let(:metadata) { {} }

    it "does not register error" do
      expect(validator).to validate_without_error(app)
    end
  end

  context "when metadata is nil" do
    let(:metadata) { nil }

    it "does not register error" do
      expect(validator).to validate_without_error(app)
    end
  end

  context "when metadata is a string" do
    let(:metadata) { "not metadata" }

    it "registers error" do
      expect(validator).to validate_with_error(app, :invalid_metadata)
    end
  end

  context "when metadata is an array" do
    let(:metadata) { [] }

    it "registers error" do
      expect(validator).to validate_with_error(app, :invalid_metadata)
    end
  end

  context "when metadata is a hash with multiple variables" do
    let(:metadata) { { :abc => 123, :def => "hi" } }

    it "does not register error" do
      expect(validator).to validate_without_error(app)
    end
  end
end
