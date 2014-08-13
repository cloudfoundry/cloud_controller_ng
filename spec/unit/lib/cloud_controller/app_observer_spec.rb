require "spec_helper"

module VCAP::CloudController
  describe AppObserver do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool, :reserve_app_memory => nil) }
    let(:dea_pool) { double(:dea_pool, :find_dea => "dea-id", :mark_app_started => nil,
      :reserve_app_memory => nil) }
    let(:staging_timeout) { 320 }
    let(:config_hash) { {staging: {timeout_in_seconds: staging_timeout}} }
    let(:blobstore_url_generator) { double(:blobstore_url_generator, :droplet_download_url => "download-url") }
    let(:tps_reporter) { double(:tps_reporter) }
    let(:diego_messenger) { Diego::Messenger.new(config_hash, message_bus, blobstore_url_generator) }
    let(:backends) { Backends.new(config_hash, message_bus, dea_pool, stager_pool) }

    before do
      allow(Diego::Messenger).to receive(:new).and_return(diego_messenger)
      Dea::Client.configure(config_hash, message_bus, dea_pool, stager_pool, blobstore_url_generator)
      AppObserver.configure(backends)
    end

    describe ".deleted" do
      let(:app) { AppFactory.make droplet_hash: nil, package_hash: nil }

      describe "stopping the application" do
        context "when diego enabled" do
          let(:config_hash) { {:diego => true} }
          let(:environment_json) { {"CF_DIEGO_BETA" => "true", "CF_DIEGO_RUN_BETA" => "true"} }

          before { app.environment_json = environment_json }

          it "stops the application" do
            expect(diego_messenger).to receive(:send_desire_request).with(app)
            AppObserver.deleted(app)
            expect(message_bus.published_messages).to be_empty
          end
        end

        context "when diego not enabled" do
          it "stops the application" do
            AppObserver.deleted(app)
            expect(message_bus).to have_published_with_message("dea.stop", droplet: app.guid)
          end
        end
      end

      it "assumes the app has a buildpack cache and enqueues a job to delete this cache" do
        expect { AppObserver.deleted(app) }.to change {
          Delayed::Job.count
        }.by(1)

        job = Delayed::Job.last
        expect(job.handler).to include(app.guid)
        expect(job.handler).to include("buildpack_cache_blobstore")
        expect(job.queue).to eq("cc-generic")
        expect(job.guid).not_to be_nil
      end

      context "when the app has a package uploaded" do
        before { app.package_hash = "abcdef" }

        it "deletes the app package" do
          delete_package_jobs = Delayed::Job.where("handler like '%package_blobstore%'")

          expect { AppObserver.deleted(app) }.to change {
            delete_package_jobs.count
          }.by(1)

          job = delete_package_jobs.last
          expect(job.handler).to include(app.guid)
          expect(job.handler).to include("package_blobstore")
          expect(job.queue).to eq("cc-generic")
          expect(job.guid).not_to be_nil
        end
      end
    end

    describe ".updated" do
      let(:package_hash) { "bar" }
      let(:environment_json) { {} }
      let(:started_instances) { 1 }
      let(:stager_task) { double(:stager_task) }

      let(:app) do
        app = VCAP::CloudController::App.make(
          last_stager_response: nil,
          instances: 1,
          package_hash: package_hash,
          droplet_hash: "initial-droplet-hash",
          name: "app-name"
        )
        allow(app).to receive(:environment_json) { environment_json }
        app
      end

      subject { AppObserver.updated(app) }

      describe "when the 'diego' flag is set" do
        let(:config_hash) { {:diego => true} }

        before do
          allow(app).to receive_messages(previous_changes: changes)

          allow(app).to receive(:started?).and_return(true)
          allow(diego_messenger).to receive(:send_stage_request).with(app)
        end

        let(:environment_json) { {"CF_DIEGO_BETA" => "true", "CF_DIEGO_RUN_BETA" => "true"} }

        context "when the app needs staging" do
          before do
            app.mark_for_restaging
          end

          context "when its state has changed" do
            let(:changes) { {:state => "anything"} }

            context "when docker_image is present" do
              before do
                allow(app).to receive(:docker_image).and_return("fake-docker-image")
              end

              it "validates for staging" do
                expect {
                  subject
                }.not_to raise_error

              end
            end

            it 'uses the diego stager to do staging' do
              subject
              expect(diego_messenger).to have_received(:send_stage_request).with(app)
            end
          end
        end

        context "when the app is already staged" do
          before do
            app.mark_as_staged
          end

          context "when the state changes" do
            let(:changes) { {:state => "anything"} }

            context "when the app is started" do
              before do
                allow(app).to receive(:started?) { true }
              end

              context "when the app requires a migration from the DEA" do
                before do
                  app.command = nil
                  app.current_droplet.detected_start_command = ""
                end

                it "restages the app" do
                  subject
                  expect(diego_messenger).to have_received(:send_stage_request).with(app)
                end

                it "marks the app as needing staging" do
                  expect { subject }.to change(app, :pending?).to(true)
                end
              end

              context "when the app is ready to run" do
                before do
                  app.command = "/run"
                end

                it "should start the app with specified number of instances" do
                  expect(Dea::Client).not_to receive(:start)
                  expect(diego_messenger).to receive(:send_desire_request).with(app)
                  subject
                end
              end
            end

            context "when the app is not started" do
              before do
                allow(app).to receive(:started?) { false }
              end

              it "should stop the app" do
                expect(Dea::Client).not_to receive(:start)
                expect(diego_messenger).to receive(:send_desire_request).with(app)
                subject
              end
            end
          end
        end

        context "when the desired instance count change" do
          context "when the app is started" do
            context "when the instance count change increases the number of instances" do
              let(:changes) { {:instances => [5, 8]} }

              before do
                allow(app).to receive(:started?).and_return(true)
              end

              it "should redesire the app" do
                expect(Dea::Client).not_to receive(:change_running_instances)
                expect(diego_messenger).to receive(:send_desire_request).with(app)
                subject
              end

              context "when the app bits were changed as well" do
                let(:package_hash) { "something new" }

                before do
                  app.mark_for_restaging
                end

                it "should start more instances of the old version" do
                  expect(Dea::Client).not_to receive(:change_running_instances)
                  expect(diego_messenger).to receive(:send_desire_request).with(app)
                  subject
                end
              end
            end

            context "when the instance count change decreases the number of instances" do
              let(:changes) { {:instances => [5, 2]} }

              before do
                allow(app).to receive(:started?) { true }
              end

              it "should redesire the app" do
                expect(Dea::Client).not_to receive(:change_running_instances)
                expect(diego_messenger).to receive(:send_desire_request).with(app)
                subject
              end
            end
          end

          context "when the app is not started" do
            let(:changes) { {:instances => [1, 2]} }

            before do
              allow(app).to receive(:started?) { false }
            end

            it "should not redesire the app" do
              expect(Dea::Client).not_to receive(:change_running_instances)
              expect(diego_messenger).not_to receive(:send_desire_request)
              subject
            end
          end
        end
      end

      describe "when the 'diego' flag is not set" do
        let(:config_hash) { {:diego => false} }

        before do
          allow(Dea::AppStagerTask).to receive(:new).
            with(config_hash,
            message_bus,
            app,
            dea_pool,
            stager_pool,
            instance_of(CloudController::Blobstore::UrlGenerator),
          ).and_return(stager_task)

          allow(stager_task).to receive(:stage) do |&callback|
            allow(app).to receive(:droplet_hash) { "staged-droplet-hash" }
            callback.call(:started_instances => started_instances)
          end

          allow(app).to receive_messages(previous_changes: changes)

          allow(Dea::Client).to receive(:start)
          allow(Dea::Client).to receive(:stop)
          allow(Dea::Client).to receive(:change_running_instances)
        end

        context "when the state changes" do
          let(:changes) { {:state => "anything"} }

          context "when the app is started" do
            before do
              app.mark_for_restaging
              allow(app).to receive(:started?) { true }
            end

            shared_examples "it stages" do
              it "initiates a staging task and waits for a response" do
                expect(stager_task).to receive(:stage) do |&callback|
                  callback.call(started_instances: 1)
                  "stager response"
                end

                expect(app).to receive(:last_stager_response=).with("stager response")

                subject
              end
            end

            context "when the app is not staged" do
              before do
                app.mark_for_restaging
              end

              context "when the app package hash is blank" do
                let(:package_hash) { '' }

                it "raises" do
                  expect {
                    subject
                  }.to raise_error(Errors::ApiError, /app package is invalid/)
                end
              end

              context "when the app package is valid" do
                let(:package_hash) { 'abc' }

                it_behaves_like "it stages"
              end

              context "when custom buildpacks are disabled" do
                context "and the app has a custom buildpack" do
                  before do
                    app.buildpack = "git://example.com/foo/bar.git"
                    app.save

                    allow(app).to receive(:custom_buildpacks_enabled?).and_return(false)
                  end

                  it "raises" do
                    expect {
                      subject
                    }.to raise_error(Errors::ApiError, /Custom buildpacks are disabled/)
                  end
                end

                context "and the app has an admin buildpack" do
                  before do
                    buildpack = Buildpack.make name: "some-admin-buildpack"
                    app.buildpack = "some-admin-buildpack"
                    app.save

                    allow(app).to receive(:custom_buildpacks_enabled?).and_return(false)
                  end

                  it_behaves_like "it stages"
                end

                context "and the app has no buildpack configured" do
                  before do
                    app.buildpack = nil
                    app.save

                    allow(app).to receive(:custom_buildpacks_enabled?).and_return(false)
                  end

                  it_behaves_like "it stages"
                end
              end

              context "when docker_image is present" do
                let(:app) { AppFactory.make docker_image: "fake-image" }

                it "raises" do
                  expect {
                    subject
                  }.to raise_error(Errors::ApiError, /Diego has not been enabled/)

                end
              end
            end

            context "when the app is already staged" do
              before do
                app.mark_as_staged
              end

              it "should not make a stager task" do
                expect(Dea::AppStagerTask).not_to receive(:new)
                subject
              end
            end

            it "should start the app with specified number of instances" do
              expect(Dea::Client).to receive(:start).with(app, :instances_to_start => app.instances - started_instances)
              subject
            end
          end

          context "when the app is not started" do
            before do
              allow(app).to receive(:started?) { false }
            end

            it "should stop the app" do
              expect(message_bus).to receive(:publish).with("dea.stop", droplet: app.guid)
              subject
            end
          end
        end

        context "when the desired instance count change" do
          context "when the app is started" do
            context "when the instance count change increases the number of instances" do
              let(:changes) { {:instances => [5, 8]} }

              before do
                allow(Dea::Client).to receive(:change_running_instances).and_call_original
                allow(app).to receive(:started?) { true }
              end

              it "should change the running instance count" do
                expect(Dea::Client).to receive(:change_running_instances).with(app, 3)
                subject
              end

              context "when the app bits were changed as well" do
                before do
                  app.mark_for_restaging
                end

                let(:package_hash) { "something new" }

                it "should start more instances of the old version" do
                  expect(message_bus).to receive(:publish) { |subject, message|
                    expect(message).to include({
                      sha1: "initial-droplet-hash"
                    })
                  }.exactly(3).times.ordered
                  subject
                end
              end
            end

            context "when the instance count change decreases the number of instances" do
              let(:changes) { {:instances => [5, 2]} }

              before do
                allow(app).to receive(:started?) { true }
              end

              it "should change the running instance count" do
                expect(Dea::Client).to receive(:change_running_instances).with(app, -3)
                subject
              end
            end
          end

          context "when the app is not started" do
            let(:changes) { {:instances => [1, 2]} }

            before do
              allow(app).to receive(:started?) { false }
            end

            it "should not change running instance count" do
              expect(Dea::Client).not_to receive(:change_running_instances)
              subject
            end
          end
        end
      end
    end
  end

  def stager_config(fog_credentials)
    {
      :resource_pool => {
        :resource_directory_key => "spec-cc-resources",
        :fog_connection => fog_credentials
      },
      :packages => {
        :app_package_directory_key => "cc-packages",
        :fog_connection => fog_credentials
      },
      :droplets => {
        :droplet_directory_key => "cc-droplets",
        :fog_connection => fog_credentials
      }
    }
  end
end
