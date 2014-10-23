require "spec_helper"

module VCAP::CloudController
  describe Backends do
    let(:config) do
      {
        diego: {
          staging: 'optional',
          running: 'optional',
        },
        diego_docker: true
      }
    end

    let(:message_bus) do
      instance_double(CfMessageBus::MessageBus)
    end

    let(:dea_pool) do
      instance_double(Dea::Pool)
    end

    let(:stager_pool) do
      instance_double(Dea::StagerPool)
    end

    let(:blobstore_url_generator) do
      instance_double(CloudController::Blobstore::UrlGenerator)
    end

    let(:messenger) do
      instance_double(Diego::Messenger)
    end

    let(:package_hash) do
      'fake-package-hash'
    end

    let(:custom_buildpacks_enabled?) do
      true
    end

    let (:buildpack) do
      instance_double(AutoDetectionBuildpack,
          custom?: false
      )
    end

    let(:docker_image) do
      nil
    end

    let(:app) do
      instance_double(App,
        docker_image: docker_image,
        package_hash: package_hash,
        buildpack: buildpack,
        custom_buildpacks_enabled?: custom_buildpacks_enabled?,
        buildpack_specified?: false,
      )
    end

    subject(:backends) do
      Backends.new(config, message_bus, dea_pool, stager_pool)
    end

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:blobstore_url_generator).and_return(blobstore_url_generator)
      allow(Dea::Backend).to receive(:new).and_call_original
      allow(Diego::Backend).to receive(:new).and_call_original
      allow(Diego::Messenger).to receive(:new).and_call_original
      allow(Diego::Docker::StagingCompletionHandler).to receive(:new).and_call_original
      allow(Diego::Traditional::StagingCompletionHandler).to receive(:new).and_call_original
    end

    describe "#validate_app_for_staging" do

      context "when the app package hash is blank" do
        let(:package_hash) { '' }

        it "raises" do
          expect {
            subject.validate_app_for_staging(app)
          }.to raise_error(Errors::ApiError, /app package is invalid/)
        end
      end

      context "when a custom buildpack is specified" do
        let (:buildpack) do
          instance_double(CustomBuildpack, custom?: true)
        end

        before do
          allow(app).to receive(:buildpack_specified?).and_return(true)
        end

        context "and custom buildpacks are disabled" do
          let(:custom_buildpacks_enabled?) do
            false
          end

          it "raises" do
            expect {
              subject.validate_app_for_staging(app)
            }.to raise_error(Errors::ApiError, /Custom buildpacks are disabled/)
          end
        end
      end

      context "when an admin buildpack is specified" do
        let (:buildpack) { instance_double(Buildpack, custom?: false) }

        before do
          allow(app).to receive(:buildpack_specified?).and_return(true)
          allow(Buildpack).to receive(:count).and_return(1)
        end

        context "and custom buildpacks are disabled" do
          let(:custom_buildpacks_enabled?) do
            false
          end

          it "does not raise" do
            expect {
              subject.validate_app_for_staging(app)
            }.to_not raise_error()
          end
        end
      end

      context "if diego docker support is not enabled" do
        before do
          config[:diego_docker] = false
        end

        context "and the app has a docker_image" do
          let(:docker_image) do
            'fake-docker-image'
          end

          it "raises" do
            expect {
              subject.validate_app_for_staging(app)
            }.to raise_error(Errors::ApiError, /Docker support has not been enabled/)
          end
        end
      end

      context "when there are no buildpacks installed on the system" do
        before { Buildpack.dataset.delete }

        context "and a custom buildpack is NOT specified" do
          it "raises NoBuildpacksFound" do
            expect {
              subject.validate_app_for_staging(app)
            }.to raise_error(Errors::ApiError, /There are no buildpacks available/)
          end
        end

        context "and a custom buildpack is specified" do
          let(:buildpack) do
            instance_double(CustomBuildpack, custom?: true)
          end

          it "does not raise" do
            expect {
              subject.validate_app_for_staging(app)
            }.not_to raise_error
          end
        end
      end
    end

    describe "#find_one_to_stage" do
      subject(:backend) do
        backends.find_one_to_stage(app)
      end

      context "when the app is configured to stage on Diego" do
        before do
          allow(app).to receive(:stage_with_diego?).and_return(true)
        end

        it "finds a Diego::Backend" do
          expect(backend).to be_a(Diego::Backend)
        end

        context "and the app is traditional" do
          it "instantiates the backend with the traditional protocol" do
            expect(Diego::Traditional::Protocol).to receive(:new).with(blobstore_url_generator)
            backend
            expect(Diego::Backend).to have_received(:new)
          end
        end

        context "and the app is docker based" do
          let(:docker_image) do
            "fake-docker-image"
          end

          it "instantiates the backend with the docker protocol" do
            expect(Diego::Docker::Protocol).to receive(:new)
            backend
            expect(Diego::Backend).to have_received(:new)
          end
        end

        context "when the operator has disabled diego staging" do
          before { config[:diego][:staging] = 'disabled' }

          it "explodes with an API error that is propagated to cf users" do
            expect {
              backend
            }.to raise_error(VCAP::Errors::ApiError, /Diego has not been enabled/)
          end
        end
      end

      context "when the app is not configured to stage on Diego" do
        before do
          allow(app).to receive(:stage_with_diego?).and_return(false)
        end

        context "when diego staging is not required" do
          it "finds a DEA::Backend" do
            expect(backend).to be_a(Dea::Backend)
          end

          it "instantiates the backend with the correct dependencies" do
            backend
            expect(Dea::Backend).to have_received(:new).with(app, config, message_bus, dea_pool, stager_pool)
          end
        end
      end
    end

    describe "#find_one_to_run" do
      subject(:backend) do
        backends.find_one_to_run(app)
      end

      context "when the app is configured to run on Diego" do
        before do
          allow(app).to receive(:run_with_diego?).and_return(true)
        end

        it "finds a Diego::Backend" do
          expect(backend).to be_a(Diego::Backend)
        end

        context "and the app is traditional" do
          it "instantiates the backend with the correct dependencies" do
            expect(Diego::Traditional::Protocol).to receive(:new).with(blobstore_url_generator)
            backend
            expect(Diego::Backend).to have_received(:new)
          end
        end

        context "and the app has a docker image" do
          let(:docker_image) do
            "fake-docker-image"
          end

          it "instantiates the backend with the correct dependencies" do
            expect(Diego::Docker::Protocol).to receive(:new)
            backend
            expect(Diego::Backend).to have_received(:new)
          end
        end

        context "when the operator has disabled diego running" do
          before { config[:diego][:running] = 'disabled' }

          it "explodes with an API error that is propagated to cf users" do
            expect {
              backend
            }.to raise_error(VCAP::Errors::ApiError, /Diego has not been enabled/)
          end
        end
      end

      context "when the app is not configured to run on Diego" do
        before do
          allow(app).to receive(:run_with_diego?).and_return(false)
        end

        context "when diego running is not required" do
          it "finds a DEA::Backend" do
            expect(backend).to be_a(Dea::Backend)
          end

          it "instantiates the backend with the correct dependencies" do
            backend
            expect(Dea::Backend).to have_received(:new).with(app, config, message_bus, dea_pool, stager_pool)
          end
        end
      end
    end

    describe "#diego_backend" do
      subject(:backend) do
        backends.diego_backend(app)
      end

      context "when the app is a docker image" do
        let(:docker_image) { "some-docker-image" }

        it "instantiates a diego backend with docker dependencies" do
          expect(app.docker_image).to_not be_nil

          expect(Diego::Docker::Protocol).to receive(:new)
          expect(Diego::Docker::StagingCompletionHandler).to receive(:new).with(backends)
          expect(backend).to be_a(Diego::Backend)
        end
      end

      context "when the app is a traditional app" do

        it "instantiates a diego backend with traditional dependencies" do
          expect(app.docker_image).to be_nil

          expect(Diego::Traditional::Protocol).to receive(:new)
          expect(Diego::Traditional::StagingCompletionHandler).to receive(:new).with(backends)
          expect(backend).to be_a(Diego::Backend)
        end
      end
    end
  end
end
