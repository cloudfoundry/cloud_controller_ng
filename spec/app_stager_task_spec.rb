require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe AppStagerTask do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool) }
    let(:config_hash) { { :config => 'hash' } }
    let(:app) { Models::App.make(:package_hash => "abc", :droplet_hash => nil, :package_state => "PENDING", :state => "STARTED", :instances => 1) }
    let(:stager_id) { "my_stager" }

    let(:options) { {} }
    let(:upload_handle) { double(:upload_handle, upload_path: '/upload/path', buildpack_cache_upload_path: '/buildpack/upload/path') }

    subject(:staging_task) { AppStagerTask.new(config_hash, message_bus, app, stager_pool) }

    let(:reply_json_error) { nil }
    let(:task_streaming_log_url) { "task-streaming-log-url" }
    let(:detected_buildpack) { nil }

    let(:first_reply_json) do
      {
        "task_id" => "task-id",
        "task_log" => "task-log",
        "task_streaming_log_url" => "task-streaming-log-url",
        "detected_buildpack" => "buildpack-name",
        "error" => nil,
        "droplet_sha1" => nil
      }
    end

    let(:reply_json) do
      {
        "task_id" => "task-id",
        "task_log" => "task-log",
        "task_streaming_log_url" => task_streaming_log_url,
        "detected_buildpack" => detected_buildpack,
        "error" => reply_json_error,
        "droplet_sha1" => "droplet-sha1"
      }
    end

    before do
      app.staged?.should be_false

      VCAP.stub(:secure_uuid) { "some_task_id" }
      stager_pool.stub(:find_stager).with(app.stack.name, 1024).and_return(stager_id)

      EM.stub(:add_timer)
      EM.stub(:defer).and_yield
      EM.stub(:schedule_sync)

      Staging.stub(:create_handle).and_return(upload_handle)
      Staging.stub(:store_droplet)
      Staging.stub(:store_buildpack_cache)
      Staging.stub(:destroy_handle)
    end

    context 'when no stager can be found' do
      let(:stager_id) { nil }

      it 'should raise an error' do
        expect {
          staging_task.stage
        }.to raise_error(Errors::StagingError, /no available stagers/)
      end
    end

    context 'when a stager can be found' do
      it 'should stop other staging tasks' do
        message_bus.should_receive(:publish).with("staging.stop", hash_including({ :app_id => app.guid }))
        staging_task.stage
      end
    end

    describe "staging" do
      describe "receiving the first response from the stager (the staging setup completion message)" do
        def stage(&blk)
          stub_schedule_sync do
            @before_staging_completion.call if @before_staging_completion
            message_bus.respond_to_request("staging.#{stager_id}.start", reply_json)
          end

          response = staging_task.stage(&blk)
          response
        end

        context "when staging setup succeeds" do
          it "returns streaming log url and rest will happen asynchronously" do
            stage.streaming_log_url.should == "task-streaming-log-url"
          end

          it "leaves the app as not having been staged" do
            stage
            expect(app).to be_pending
          end

          it "creates upload handle for stager to upload droplet" do
            Staging.should_receive(:create_handle).and_return(upload_handle)
            stage
          end

          context "when there are available stagers" do
            it "stops other staging tasks and starts a new one" do
              message_bus.should_receive(:publish).with("staging.stop", anything)
              message_bus.should_receive(:publish).with("staging.my_stager.start", staging_task.staging_request)

              stage
            end

            it "saves staging task id" do
              stage
              app.staging_task_id.should eq("some_task_id")
            end
          end
          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { Staging.droplet_exists?(app) }.from(false)
          end

          it "does not save the detected buildpack" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.detected_buildpack }.from(nil)
          end

          it "does not call provided callback (not yet)" do
            callback_called = false
            ignore_error(Errors::StagingError) do
              stage { callback_called = true }
            end
            callback_called.should be_false
          end
        end

        context "when staging setup fails without a reason" do
          let(:reply_json) { 'invalid-json' }

          it "raises a StagingError" do
            expect {
              stage
            }.to raise_error(Errors::StagingError, /failed to stage/)
          end

          it "removes upload handle" do
            Staging.should_receive(:destroy_handle).with(upload_handle)
            ignore_error(Errors::StagingError) { stage }
          end
          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { Staging.droplet_exists?(app) }.from(false)
          end

          it "does not save the detected buildpack" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.detected_buildpack }.from(nil)
          end

          it "does not call provided callback (not yet)" do
            callback_called = false
            ignore_error(Errors::StagingError) do
              stage { callback_called = true }
            end
            callback_called.should be_false
          end
          it "marks the app as having failed to stage" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to change { app.failed? }.to(true)
          end
        end

        context "when staging setup returned an error response" do
          let(:reply_json_error) { "staging failed" }

          it "raises a StagingError" do
            expect { stage }.to raise_error(Errors::StagingError, /failed to stage/)
          end

          it "removes upload handle" do
            Staging.should_receive(:destroy_handle).with(upload_handle)
            ignore_error(Errors::StagingError) { stage }
          end
          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { Staging.droplet_exists?(app) }.from(false)
          end

          it "does not save the detected buildpack" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.detected_buildpack }.from(nil)
          end

          it "does not call provided callback (not yet)" do
            callback_called = false
            ignore_error(Errors::StagingError) do
              stage { callback_called = true }
            end
            callback_called.should be_false
          end
          it "marks the app as having failed to stage" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to change { app.failed? }.to(true)
          end
        end

        context "when an exception occurs" do
          def reply_with_staging_completion
            message_bus.respond_to_request("staging.#{stager_id}.start", {})
          end

          it "copes when the app is destroyed halfway between staging (currently we dont know why this happened but seen on tabasco)" do
            VCAP::CloudController::AppStagerTask::Response.stub(:new) do
              app.destroy # We saw that app maybe destroyed half-way through staging
              raise ArgumentError, "Some Fake Error"
            end

            expect { stage }.to raise_error ArgumentError, "Some Fake Error"
          end
        end
      end

      describe "receiving staging completion message" do
        def stage(&blk)
          stub_schedule_sync do
            @before_staging_completion.call if @before_staging_completion
            message_bus.respond_to_request("staging.#{stager_id}.start", first_reply_json)
          end

          staging_task.stage(&blk)
          message_bus.respond_to_request("staging.#{stager_id}.start", reply_json)
        end

        context "when app staging succeeds" do
          let(:detected_buildpack) { "buildpack-name" }

          context "when no other staging has happened" do
            it "stages the app" do
              expect {
                stage
              }.to change {
                [app.staged?, app.needs_staging?]
              }.from([false, true]).to([true, false])
            end

            it "stores droplet" do
              Staging.should_receive(:store_droplet).with(app, '/upload/path')
              stage
            end

            it "updates droplet hash on the app" do
              expect { stage }.to change { app.droplet_hash }.from(nil).to("droplet-sha1")
            end

            it "marks the app as having staged successfully" do
              expect { stage }.to change { app.staged? }.to(true)
            end

            it "saves the detected buildpack" do
              expect { stage }.to change { app.detected_buildpack }.from(nil)
            end

            it "removes upload handle" do
              Staging.should_receive(:destroy_handle).with(upload_handle)
              stage
            end

            it "calls provided callback" do
              callback_called = false
              stage { callback_called = true }
              callback_called.should be_true
            end
          end

          context "when other staging has happened" do
            before do
              @before_staging_completion = -> {
                app.staging_task_id = "another-staging-task-id"
                app.save
              }
            end

            it "raises a StagingError" do
              expect {
                stage
              }.to raise_error(
                       Errors::StagingError,
                       /another staging request was initiated/
                   )
            end

            it "does not store droplet" do
              expect {
                ignore_error(Errors::StagingError) { stage }
              }.to_not change { Staging.droplet_exists?(app) }.from(false)
            end

            it "does not update droplet hash on the app" do
              expect {
                ignore_error(Errors::StagingError) { stage }
              }.to_not change {
                app.refresh
                app.droplet_hash
              }.from("droplet-hash")
            end

            it "does not save the detected buildpack" do
              expect {
                ignore_error(Errors::StagingError) { stage }
              }.to_not change { app.detected_buildpack }.from(nil)
            end

            it "does not call provided callback" do
              callback_called = false
              ignore_error(Errors::StagingError) do
                stage { callback_called = true }
              end
              callback_called.should be_false
            end
          end
        end

        context "when app staging fails without a reason" do
          let(:reply_json) { nil }
          let(:options) { { :invalid_json => true } }

          it "logs StagingError instead of raising to avoid stopping main runloop" do
            logger = mock(:logger, :info => nil)
            logger.should_receive(:error).with(/failed to stage/)

            Steno.stub(:logger => logger)
            stage
          end

          it "removes upload handle" do
            Staging.should_receive(:destroy_handle).with(upload_handle)
            stage
          end
          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { Staging.droplet_exists?(app) }.from(false)
          end

          it "does not save the detected buildpack" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.detected_buildpack }.from(nil)
          end

          it "does not call provided callback (not yet)" do
            callback_called = false
            ignore_error(Errors::StagingError) do
              stage { callback_called = true }
            end
            callback_called.should be_false
          end
          it "marks the app as having failed to stage" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to change { app.failed? }.to(true)
          end
        end

        context "when app staging returned an error response" do
          let(:reply_json_error) { "staging failed" }

          it "logs StagingError instead of raising to avoid stopping main runloop" do
            logger = mock(:logger, :info => nil)
            logger.should_receive(:error) do |msg|
              msg.should match(/failed to stage/)
            end

            Steno.stub(:logger => logger)
            stage
          end

          it "removes upload handle" do
            Staging.should_receive(:destroy_handle).with(upload_handle)
            stage
          end
          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { Staging.droplet_exists?(app) }.from(false)
          end

          it "does not save the detected buildpack" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.detected_buildpack }.from(nil)
          end

          it "does not call provided callback (not yet)" do
            callback_called = false
            ignore_error(Errors::StagingError) do
              stage { callback_called = true }
            end
            callback_called.should be_false
          end
          it "marks the app as having failed to stage" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to change { app.failed? }.to(true)
          end
        end
      end
    end

    describe ".staging_request" do
      let(:staging_task) { AppStagerTask.new(nil, message_bus, app, stager_pool) }
      let(:app) { Models::App.make :droplet_hash => nil, :package_state => "PENDING" }
      let(:dea_start_message) { {:dea_client_message => "start app message"} }

      before do
        3.times do
          instance = Models::ManagedServiceInstance.make(:space => app.space)
          binding = Models::ServiceBinding.make(:app => app, :service_instance => instance)
          app.add_service_binding(binding)
        end

        DeaClient.stub(:start_app_message).and_return(dea_start_message)
      end

      it "includes app guid, task id and download/upload uris" do
        Staging.stub(:app_uri).with(app).and_return("http://www.app.uri")
        Staging.stub(:droplet_upload_uri).with(app).and_return("http://www.droplet.upload.uri")
        Staging.stub(:buildpack_cache_download_uri).with(app).and_return("http://www.buildpack.cache.download.uri")
        Staging.stub(:buildpack_cache_upload_uri).with(app).and_return("http://www.buildpack.cache.upload.uri")

        request = staging_task.staging_request

        request[:app_id].should == app.guid
        request[:task_id].should eq(staging_task.task_id)
        request[:download_uri].should eq("http://www.app.uri")
        request[:upload_uri].should eq("http://www.droplet.upload.uri")
        request[:buildpack_cache_upload_uri].should eq("http://www.buildpack.cache.upload.uri")
        request[:buildpack_cache_download_uri].should eq("http://www.buildpack.cache.download.uri")
      end

      it "includes misc app properties" do
        request = staging_task.staging_request
        request[:properties][:meta].should be_kind_of(Hash)
      end

      it "includes service binding properties" do
        request = staging_task.staging_request
        request[:properties][:services].count.should == 3
        request[:properties][:services].each do |service|
          service[:credentials].should be_kind_of(Hash)
          service[:options].should be_kind_of(Hash)
        end
      end

      context "when app does not have buildpack" do
        it "returns nil for buildpack" do
          app.buildpack = nil
          request = staging_task.staging_request
          request[:properties][:buildpack].should be_nil
        end
      end

      context "when app has a buildpack" do
        it "returns url for buildpack" do
          app.buildpack = "git://example.com/foo.git"
          request = staging_task.staging_request
          request[:properties][:buildpack].should == "git://example.com/foo.git"
        end
      end

      it "includes start app message" do
        request = staging_task.staging_request
        request[:start_message].should include dea_start_message
      end

      it "includes app index 0" do
        request = staging_task.staging_request
        request[:start_message].should include ({:index => 0})
      end

      it "overwrites droplet sha" do
        request = staging_task.staging_request
        request[:start_message].should include ({:sha1 => nil})
      end

      it "overwrites droplet download uri" do
        request = staging_task.staging_request
        request[:start_message].should include ({:executableUri => nil})
      end
    end
  end
end

def stub_schedule_sync(&before_resolve)
  EM.stub(:schedule_sync) do |&blk|
    promise = VCAP::Concurrency::Promise.new

    begin
      if blk.arity > 0
        blk.call(promise)
      else
        promise.deliver(blk.call)
      end
    rescue Exception => e
      promise.fail(e)
    end

    # Call before_resolve block before trying to resolve the promise
    before_resolve.call

    promise.resolve
  end
end

def ignore_error(error_class)
  yield
rescue error_class
end
