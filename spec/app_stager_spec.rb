require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe AppStager do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool) }
    let(:config_hash) { {:config => 'hash'} }

    before { AppStager.configure(config_hash, message_bus, stager_pool) }

    describe ".run" do
      it "registers subscriptions for dea_pool" do
        stager_pool.should_receive(:register_subscriptions)
        VCAP::CloudController::AppStager.run
      end
    end

    describe ".stage_app (stages sync/async)" do
      context "when the app package hash is nil" do
        let(:app) { double(:app, :package_hash => nil) }

        it "raises" do
          expect {
            AppStager.stage_app(app)
          }.to raise_error(Errors::AppPackageInvalid)
        end
      end

      context "when the app package hash is blank" do
        let(:app) { double(:app, :package_hash => '') }

        it "raises" do
          expect {
            AppStager.stage_app(app)
          }.to raise_error(Errors::AppPackageInvalid)
        end
      end

      context "when the app package is valid" do
        let(:app) { double(:app, :package_hash => 'abc') }

        it 'should make a task and stage it' do
          task = double(:stager_task)
          opts = {:foo => 'bar'}

          AppStagerTask.stub(:new).with(config_hash, message_bus, app, stager_pool).and_return(task)
          task.should_receive(:stage).with(opts).and_yield

          called = false
          AppStager.stage_app(app, opts) do
            called = true
          end
          expect(called).to eql(true)
        end
      end
    end

    describe '.delete_droplet' do
      let(:app) { Models::App.make }
      before do
        AppStager.unstub(:delete_droplet)
      end

      it 'should delete the droplet from staging' do
        Staging.should_receive(:delete_droplet).with(app.guid)
        AppStager.delete_droplet(app)
      end

      context "when droplet does not exist" do
        context "local fog provider" do
          it "does nothing" do
            Staging.droplet_exists?(app.guid).should == false
            AppStager.delete_droplet(app)
            Staging.droplet_exists?(app.guid).should == false
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
            Staging.droplet_exists?(app.guid).should == false
            AppStager.delete_droplet(app)
            Staging.droplet_exists?(app.guid).should == false
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
            Staging.droplet_exists?(app.guid).should == false
            AppStager.delete_droplet(app)
            Staging.droplet_exists?(app.guid).should == false
          end
        end

        context "Non NotFound error" do
          before do
            Staging.should_receive(:droplet_dir).and_raise(StandardError.new("This is an intended error."))
          end

          it "should not rescue non-NotFound errors" do
            expect { AppStager.delete_droplet(app) }.to raise_error(StandardError)
          end
        end
      end

      context "when droplet exists" do
        before { Staging.store_droplet(app.guid, droplet.path) }

        let(:droplet) do
          Tempfile.new(app.guid).tap do |f|
            f.write("droplet-contents")
            f.close
          end
        end

        it "deletes the droplet if it exists" do
          expect {
            AppStager.delete_droplet(app)
          }.to change {
            Staging.droplet_exists?(app.guid)
          }.from(true).to(false)
        end

        # Fog (local) tries to delete parent directories that might be empty
        # when deleting a file. Sometimes it will fail due to a race
        # since those directories might have been populated in between
        # emptiness check and actual deletion.
        it "does not raise error when it fails to delete directory structure" do
          Fog::Collection
          .any_instance
          .should_receive(:destroy)
          .and_raise(Errno::ENOTEMPTY)
          AppStager.delete_droplet(app)
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