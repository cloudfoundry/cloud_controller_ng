require "spec_helper"

describe DockerPolicy do
  describe "env" do
    let(:app) { VCAP::CloudController::AppFactory.make }
    let(:diego_enabled) { true }
    let(:docker_enabled) { true }
    subject(:validator) { DockerPolicy.new(app, diego_enabled, docker_enabled) }

    it "disallows a custom buildpack and a docker_image" do
      app.docker_image = 'fake-image'
      app.buildpack = "git://user@github.com:repo"

      expect(validator).to validate_with_error(app, :docker_image, DockerPolicy::INVALID_ERROR_MSG)
    end

    it "disallows an admin buildpack and a docker_image" do
      admin_buildpack = VCAP::CloudController::Buildpack.make
      app.docker_image = 'fake-image'
      app.buildpack = admin_buildpack.name

      expect(validator).to validate_with_error(app, :docker_image, DockerPolicy::INVALID_ERROR_MSG)
    end

    context "when diego is disabled" do
      let(:diego_enabled) { false }

      it "disallows a docker_image" do
        app.docker_image = 'fake-image'
        expect(validator).to validate_with_error(app, :docker_image, DockerPolicy::DISABLED_ERROR_MSG)
      end
    end

    context "when docker is disabled" do
      let(:docker_enabled) { false }

      it "disallows a docker_image" do
        app.docker_image = 'fake-image'
        expect(validator).to validate_with_error(app, :docker_image, DockerPolicy::DISABLED_ERROR_MSG)
      end
    end

    it "allows a docker_image without a buildpack" do
      app.docker_image = 'fake-image'
      expect(validator).to validate_without_error(app)
    end

    it "allows anything without a docker_image through" do
      expect(validator).to validate_without_error(app)
    end
  end
end
