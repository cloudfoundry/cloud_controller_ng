require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe AppManager do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool) }
    let(:config_hash) { {:config => 'hash'} }

    before { AppManager.configure(config_hash, message_bus, stager_pool) }

    describe ".run" do
      it "registers subscriptions for dea_pool" do
        stager_pool.should_receive(:register_subscriptions)
        VCAP::CloudController::AppManager.run
      end
    end

    describe '.delete_droplet' do
      let(:app) { Models::App.make }
      before do
        AppManager.unstub(:delete_droplet)
      end

      it 'should delete the droplet from staging' do
        StagingsController.should_receive(:delete_droplet).with(app)
        AppManager.delete_droplet(app)
      end

      context "when droplet does not exist" do
        context "local fog provider" do
          it "does nothing" do
            StagingsController.droplet_exists?(app).should == false
            AppManager.delete_droplet(app)
            StagingsController.droplet_exists?(app).should == false
          end
        end

        context "AWS fog provider" do
          before do
            Fog.unmock!

            fog_credentials = {
              :provider => "AWS",
              :aws_access_key_id => "fake_aws_key_id",
              :aws_secret_access_key => "fake_secret_access_key",
            }

            config_override(config_override(stager_config(fog_credentials)))
            config
          end

          it "does nothing" do
            StagingsController.droplet_exists?(app).should == false
            AppManager.delete_droplet(app)
            StagingsController.droplet_exists?(app).should == false
          end
        end

        context "HP fog provider" do
          before do
            Fog.unmock!

            fog_credentials = {
              :provider => "HP",
              :hp_access_key => "fake_credentials",
              :hp_secret_key => "fake_credentials",
              :hp_tenant_id => "fake_credentials",
              :hp_auth_uri => 'https://auth.example.com:5000/v2.0/',
              :hp_use_upass_auth_style => true,
              :hp_avl_zone => 'nova'
            }

            config_override(stager_config(fog_credentials))
            config
          end

          it "does nothing" do
            StagingsController.droplet_exists?(app).should == false
            AppManager.delete_droplet(app)
            StagingsController.droplet_exists?(app).should == false
          end
        end

        context "Non NotFound error" do
          before do
            StagingsController.blob_store.stub(:files).and_raise(StandardError.new("This is an intended error."))
          end

          it "should not rescue non-NotFound errors" do
            expect { AppManager.delete_droplet(app) }.to raise_error(StandardError)
          end
        end
      end

      context "when droplet exists" do
        before { StagingsController.store_droplet(app, droplet.path) }

        let(:droplet) do
          Tempfile.new(app.guid).tap do |f|
            f.write("droplet-contents")
            f.close
          end
        end

        it "deletes the droplet if it exists" do
          expect {
            AppManager.delete_droplet(app)
          }.to change {
            StagingsController.droplet_exists?(app)
          }.from(true).to(false)
        end

        # Fog (local) tries to delete parent directories that might be empty
        # when deleting a file. Sometimes it will fail due to a race
        # since those directories might have been populated in between
        # emptiness check and actual deletion.
        it "does not raise error when it fails to delete directory structure" do
          Fog::Storage::HP::File
          .any_instance
          .should_receive(:destroy)
          .and_raise(Errno::ENOTEMPTY)

          AppManager.delete_droplet(app)
        end
      end
    end

    describe ".stop_droplet" do
      let(:app) { Models::App.make }

      context "when the app is started" do
        before do
          app.state = "STARTED"
        end

        it 'should tell the dea client to stop the app' do
          DeaClient.should_receive(:stop).with(app)
          AppManager.stop_droplet(app)
        end
      end

      context "when the app is stopped" do
        before do
          app.state = "STOPPED"
        end

        it 'should tell the dea client to stop the app' do
          DeaClient.should_not_receive(:stop)
          AppManager.stop_droplet(app)
        end
      end
    end

    describe ".app_changed" do
      let(:package_hash) { "bar" }
      let(:needs_staging) { false }
      let(:started_instances) { 1 }
      let(:stager_task) { double(:stager_task) }

      let(:app) do
        double(:app,
          :last_stager_response= => nil,
          :needs_staging? => needs_staging,
          :instances => 1,
          :guid => "foo",
          :package_hash => package_hash
        )
      end

      before do
        AppStagerTask.stub(:new).with(config_hash, message_bus, app, stager_pool).and_return(stager_task)

        stager_task.stub(:stage) do |&callback|
          callback.call(:started_instances => started_instances)
        end
      end

      shared_examples_for(:stages_if_needed) do
        context "when the app needs staging" do
          let(:needs_staging) { true }

          context "when the app package hash is nil" do
            let(:package_hash) { nil }

            it "raises" do
              expect {
                subject
              }.to raise_error(Errors::AppPackageInvalid)
            end
          end

          context "when the app package hash is blank" do
            let(:package_hash) { '' }

            it "raises" do
              expect {
                subject
              }.to raise_error(Errors::AppPackageInvalid)
            end
          end

          context "when the app package is valid" do
            let(:package_hash) { 'abc' }
            let(:started_instances) { 1 }

            it "should make a task and stage it" do
              stager_task.should_receive(:stage) do |&callback|
                callback.call(:started_instances => started_instances)
                "stager response"
              end

              app.should_receive(:last_stager_response=).with("stager response")

              subject
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
          health_manager_client = CloudController::DependencyLocator.instance.health_manager_client
          health_manager_client.should_receive(:notify_app_updated).with("foo")
          subject
        end
      end

      subject { AppManager.app_changed(app, changes) }

      before do
        DeaClient.stub(:start)
        DeaClient.stub(:stop)
        DeaClient.stub(:change_running_instances)
      end

      context "when the state is changed" do
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

      context "when the instances count is changed" do
        let(:changes) { { :instances => [5, 2] } }

        context "when the app is started" do
          before do
            app.stub(:started?) { true }
          end

          it_behaves_like :stages_if_needed
          it_behaves_like :sends_droplet_updated

          it 'should change the running instance count' do
            DeaClient.should_receive(:change_running_instances).with(app, -3)
            subject
          end
        end

        context "when the app is not started" do
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
