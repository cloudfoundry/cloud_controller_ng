require "spec_helper"

describe CustomBuildpackPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }
  let(:buildpack) { double("build") }

  subject(:validator) { CustomBuildpackPolicy.new(app, custom_buildpacks_enabled)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }
    allow(app).to receive(:buildpack).and_return(buildpack)
  end

  context "when buildpack changes" do
    before do
      allow(app).to receive(:buildpack_changed?).and_return(true)
    end

    context "when custom buildpacks are enabled (by default)" do
      let(:custom_buildpacks_enabled) { true }

      it "buildpack is not custom" do
        allow(buildpack).to receive(:custom?).and_return(false)
        expect(validator).to validate_without_error(app)
      end

      it "buildpack is custom" do
        allow(buildpack).to receive(:custom?).and_return(true)
        expect(validator).to validate_without_error(app)
      end
    end

    context "when custom buildpacks are disabled" do
      let(:custom_buildpacks_enabled) { false }

      it "buildpack is not custom" do
        allow(buildpack).to receive(:custom?).and_return(false)
        expect(validator).to validate_without_error(app)
      end

      it "buildpack is custom" do
        allow(buildpack).to receive(:custom?).and_return(true)
        expect(validator).to validate_with_error(app, CustomBuildpackPolicy::ERROR_MSG)
      end
    end
  end

  context "when buildpack did not change" do
    let(:custom_buildpacks_enabled) { false }

    before do
      allow(app).to receive(:buildpack_changed?).and_return(false)
    end

    it "does not raise any errors" do
      expect(validator).to validate_without_error(app)
    end
  end
end
