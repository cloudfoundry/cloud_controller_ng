require "spec_helper"

module VCAP::CloudController
  describe AppObserver do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool, :reserve_app_memory => nil) }
    let(:dea_pool) { double(:dea_pool, :find_dea => "dea-id", :mark_app_started => nil,
                            :reserve_app_memory => nil) }
    let(:staging_timeout) { 320 }
    let(:config_hash) { { staging: { timeout_in_seconds: staging_timeout } } }
    let(:blobstore_url_generator) { double(:blobstore_url_generator, :droplet_download_url => "download-url") }

    before do
      DeaClient.configure(config_hash, message_bus, dea_pool, stager_pool, blobstore_url_generator)
      AppObserver.configure(config_hash, message_bus, dea_pool, stager_pool)
    end

    describe ".run" do
      it "registers subscriptions for dea_pool" do
        stager_pool.should_receive(:register_subscriptions)
        AppObserver.run
      end
    end

    describe ".deleted" do
      let(:app) { AppFactory.make droplet_hash: nil, package_hash: nil }

      it "stops the application" do
        AppObserver.deleted(app)
        expect(message_bus).to have_published_with_message("dea.stop", droplet: app.guid)
      end

      context "when the app has a droplet" do
        before { app.droplet_hash = "abcdef" }

        it "enqueue a jobs to delete the buildpack cache" do
          expect { AppObserver.deleted(app) }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.handler).to include(app.guid)
          expect(job.handler).to include("buildpack_cache_blobstore")
          expect(job.queue).to eq("cc-generic")
          expect(job.guid).not_to be_nil
        end


      end

      context "when the app has a package uploaded" do
        before { app.package_hash = "abcdef" }

        it "deletes the app package" do
          expect { AppObserver.deleted(app) }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.handler).to include(app.guid)
          expect(job.handler).to include("package_blobstore")
          expect(job.queue).to eq("cc-generic")
          expect(job.guid).not_to be_nil
        end
      end
    end

    describe ".updated" do
      let(:package_hash) { "bar" }
      let(:needs_staging) { false }
      let(:environment_json) { {} }
      let(:started_instances) { 1 }
      let(:stager_task) { double(:stager_task) }

      let(:app) do
        app = VCAP::CloudController::App.make(
            last_stager_response: nil,
            instances:            1,
            package_hash:         package_hash,
            droplet_hash:         "initial-droplet-hash",
            name:                 "app-name"
        )
        app.stub(:needs_staging?) { needs_staging }
        app.stub(:environment_json) { environment_json }
        app
      end

      subject { AppObserver.updated(app) }

      describe "when the 'diego' flag is set" do
        before { config_hash[:diego] = true }
        let(:environment_json) { {"CF_DIEGO_BETA"=>"true"} }

        let(:needs_staging) { true }

        it 'uses the diego stager to do staging' do
          DiegoStagerTask.should_receive(:new).
              with(staging_timeout,
                   message_bus,
                   app,
                   instance_of(CloudController::Blobstore::UrlGenerator),
          ).and_return(stager_task)

          stager_task.stub(:stage) do |&callback|
            app.stub(:droplet_hash) { "staged-droplet-hash" }
            callback.call(:started_instances => started_instances)
          end

          app.stub(previous_changes: { :state => "anything" })
          app.stub(:started?).and_return(true)

          subject
        end
      end

      describe "when the 'diego' flag is not set" do
        let(:config_hash) { { :diego => false } }
        before do
         AppStagerTask.stub(:new).
            with(config_hash,
                 message_bus,
                 app,
                 dea_pool,
                 stager_pool,
                 instance_of(CloudController::Blobstore::UrlGenerator),
         ).and_return(stager_task)

          stager_task.stub(:stage) do |&callback|
            app.stub(:droplet_hash) { "staged-droplet-hash" }
            callback.call(:started_instances => started_instances)
          end

          app.stub(previous_changes: changes)

          DeaClient.stub(:start)
          DeaClient.stub(:stop)
          DeaClient.stub(:change_running_instances)
        end

        shared_examples_for(:stages_if_needed) do
          def self.it_stages
            it "initiates a staging task and waits for a response" do
              stager_task.should_receive(:stage) do |&callback|
                callback.call(started_instances: 1)
                "stager response"
              end

              app.should_receive(:last_stager_response=).with("stager response")

              subject
            end
          end

          context "when the app needs staging" do
            let(:needs_staging) { true }

            context "when the app package hash is nil" do
              let(:package_hash) { nil }

              it "raises" do
                expect {
                  subject
                }.to raise_error(Errors::ApiError, /app package is invalid/)
              end
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

              it_stages
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
                  buildpack     = Buildpack.make name: "some-admin-buildpack"
                  app.buildpack = "some-admin-buildpack"
                  app.save

                  allow(app).to receive(:custom_buildpacks_enabled?).and_return(false)
                end

                it_stages
              end

              context "and the app has no buildpack configured" do
                before do
                  app.buildpack = nil
                  app.save

                  allow(app).to receive(:custom_buildpacks_enabled?).and_return(false)
                end

                it_stages
              end
            end
          end

          context "when staging is not needed" do
            let(:needs_staging) { false }

            it "should not make a stager task" do
              AppStagerTask.should_not_receive(:new)
              subject
            end
          end
        end

        shared_examples_for(:sends_droplet_updated) do
          it "should send droplet updated message" do
            subject
            expect(message_bus).to have_published_with_message("droplet.updated", droplet: app.guid)
          end
        end

        context "when the state changes" do
          let(:changes) { { :state => "anything" } }

          context "when the app is started" do
            let(:needs_staging) { true }

            before do
              app.stub(:started?) { true }
            end

            it_behaves_like :stages_if_needed
            it_behaves_like :sends_droplet_updated

            it "should start the app with specified number of instances" do
              DeaClient.should_receive(:start).with(app, :instances_to_start => app.instances - started_instances)
              subject
            end
          end

          context "when the app is not started" do
            before do
              app.stub(:started?) { false }
            end

            it_behaves_like :sends_droplet_updated

            it "should stop the app" do
              DeaClient.should_receive(:stop).with(app)
              subject
            end
          end
        end

        context "when the desired instance count change" do
          context "when the app is started" do
            context "when the instance count change increases the number of instances" do
              let(:changes) { { :instances => [5, 8] } }

              before do
                DeaClient.unstub(:change_running_instances)
                app.stub(:started?) { true }
              end

              it_behaves_like :sends_droplet_updated

              it "should change the running instance count" do
                DeaClient.should_receive(:change_running_instances).with(app, 3)
                subject
              end

              context "when the app bits were changed as well" do
                let(:needs_staging) { true }
                let(:package_hash) { "something new" }

                it "should start more instances of the old version" do
                  message_bus.should_receive(:publish) do |subject, message|
                    expect(message).to include({
                                                   sha1: "initial-droplet-hash"
                                               })
                  end.exactly(3).times.ordered
                  message_bus.should_receive(:publish).with("droplet.updated", anything).ordered
                  subject
                end
              end
            end

            context "when the instance count change decreases the number of instances" do
              let(:changes) { { :instances => [5, 2] } }

              before do
                app.stub(:started?) { true }
              end

              it_behaves_like :sends_droplet_updated

              it "should change the running instance count" do
                DeaClient.should_receive(:change_running_instances).with(app, -3)
                subject
              end
            end
          end

          context "when the app is not started" do
            let(:changes) { { :instances => [1, 2] } }

            before do
              app.stub(:started?) { false }
            end

            it "should not change running instance count" do
              DeaClient.should_not_receive(:change_running_instances)
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
            :fog_connection         => fog_credentials
        },
        :packages      => {
            :app_package_directory_key => "cc-packages",
            :fog_connection            => fog_credentials
        },
        :droplets      => {
            :droplet_directory_key => "cc-droplets",
            :fog_connection        => fog_credentials
        }
    }
  end
end
