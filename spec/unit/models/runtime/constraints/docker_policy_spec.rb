require 'spec_helper'

RSpec.describe DockerPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(docker_image: 'some-image:latest') }

  subject(:validator) { DockerPolicy.new(app) }

  context 'when a buildpack is specified' do
    before do
      allow(app).to receive(:buildpack_specified?).and_return(true)
    end

    it 'registers an appropriate error' do
      expect(validator).to validate_with_error(app, :docker_image, DockerPolicy::BUILDPACK_DETECTED_ERROR_MSG)
    end
  end

  context 'when Docker is disabled' do
    before do
      VCAP::CloudController::FeatureFlag.create(name: 'diego_docker', enabled: false)
    end

    context 'when app is being started' do
      before do
        allow(app).to receive(:being_started?).and_return(true)
      end

      it 'registers an appropriate error' do
        expect(validator).to validate_with_error(app, :docker, :docker_disabled)
      end
    end

    context 'when app is being stopped' do
      before do
        allow(app).to receive(:being_started?).and_return(false)
      end

      it 'does not register an error' do
        expect(validator).to validate_without_error(app)
      end
    end
  end

  context 'when Docker is enabled' do
    before do
      VCAP::CloudController::FeatureFlag.create(name: 'diego_docker', enabled: true)
    end

    it 'does not register an error' do
      expect(validator).to validate_without_error(app)
    end
  end

  context 'when complete set of Docker credentials is supplied' do
    before do
      allow(app).to receive(:docker_credentials_json).and_return({ 'docker_user' => 'user', 'docker_password' => 'pass', 'docker_email' => 'someone@somewhere.com' })
    end

    it 'does not register an error' do
      expect(validator).to validate_without_error(app)
    end
  end

  context 'when an incomplete set of Docker credentials is supplied' do
    before do
      allow(app).to receive(:docker_credentials_json).and_return({ 'docker_email' => 'someone@somewhere.com' })
    end

    it 'does not register an error' do
      expect(validator).to validate_with_error(app, :docker_credentials, DockerPolicy::DOCKER_CREDENTIALS_ERROR_MSG)
    end
  end

  context 'when attempting to switch to docker from buildpack' do
    let(:parent_app) { VCAP::CloudController::AppModel.make(:buildpack) }
    let!(:app) { VCAP::CloudController::App.make(app: parent_app) }

    it 'registers an error' do
      app.docker_image = 'image'
      expect(validator).to validate_with_error(app, :docker_image, DockerPolicy::LIFECYCLE_CHANGE_ERROR_MSG)
    end
  end
end
