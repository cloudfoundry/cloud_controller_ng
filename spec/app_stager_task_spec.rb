require "spec_helper"

module VCAP::CloudController
  describe AppStagerTask do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:stager_pool) { double(:stager_pool) }
    let(:config_hash) { { :config => 'hash' } }
    let(:app) { App.make(:package_hash => "abc", :droplet_hash => nil, :package_state => "PENDING", :state => "STARTED", :instances => 1) }
    let(:stager_id) { "my_stager" }
    let(:blobstore_url_generator) { double.as_null_object }

    let(:options) { {} }
    subject(:staging_task) { AppStagerTask.new(config_hash, message_bus, app, stager_pool, blobstore_url_generator) }

    let(:reply_json_error) { nil }
    let(:task_streaming_log_url) { "task-streaming-log-url" }
    let(:detected_buildpack) { nil }
    let(:droplet) do
      CloudController::Droplet.new(app, StagingsController.blobstore)
    end

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

      StagingsController.stub(:store_droplet)
      StagingsController.stub(:store_buildpack_cache)
      # Some other tests inter
      Buildpack.stub(:list_admin_buildpacks).and_return([])
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

    context 'when the app memory requirement exceeds the staging memory requirement (1024)' do
      it 'should request a stager with the app memory requirement' do
        app.memory = 1025
        stager_pool.should_receive(:find_stager).with(app.stack.name, 1025).and_return(stager_id)
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
            }.to_not change { droplet.exists? }.from(false)
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

          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { droplet.exists? }.from(false)
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
            }.to change { app.staging_failed? }.to(true)
          end
        end

        context "when staging setup returned an error response" do
          let(:reply_json_error) { "staging failed" }

          it "raises a StagingError" do
            expect { stage }.to raise_error(Errors::StagingError, /failed to stage/)
          end

          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { stage }
            }.to_not change { droplet.exists? }.from(false)
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
            }.to change { app.staging_failed? }.to(true)
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
          context "and the app was staged and started by the DEA" do
            let(:detected_buildpack) { "buildpack-name" }

            context "when no other staging has happened" do
              before do
                DeaClient.dea_pool.stub(:mark_app_started)
              end

              it "saves the detected buildpack" do
                expect { stage }.to change { app.refresh.detected_buildpack }.from(nil)
              end

              it "does not clobber other attributes that changed between staging" do
                # fake out the app refresh as the race happens after it
                app.stub(:refresh)

                other_app_ref = App.find(guid: app.guid)
                other_app_ref.command = "some other command"
                other_app_ref.save

                expect { stage }.to_not change {
                  other_app_ref.refresh.command
                }
              end

              it "marks app started in dea pool" do
                DeaClient.dea_pool.should_receive(:mark_app_started).with({ :dea_id => stager_id, :app_id => app.guid })
                stage
              end

              it "calls provided callback" do
                callback_options = nil
                stage { |options| callback_options = options }
                callback_options[:started_instances].should equal(1)
              end
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
              }.to_not change { droplet.exists? }.from(false)
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
            logger = double(:logger, :info => nil)
            logger.should_receive(:error).with(/failed to stage/)

            Steno.stub(:logger => logger)
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
            }.to_not change { droplet.exists? }.from(false)
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
            }.to change { app.staging_failed? }.to(true)
          end
        end

        context "when app staging returned an error response" do
          let(:reply_json_error) { "staging failed" }

          it "logs StagingError instead of raising to avoid stopping main runloop" do
            logger = double(:logger, :info => nil)
            logger.should_receive(:error) do |msg|
              msg.should match(/failed to stage/)
            end

            Steno.stub(:logger => logger)
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
            }.to_not change { droplet.exists? }.from(false)
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
            }.to change { app.staging_failed? }.to(true)
          end
        end
      end
    end

    describe ".staging_request" do
      let(:app) { App.make :droplet_hash => nil, :package_state => "PENDING" }
      let(:dea_start_message) { { :dea_client_message => "start app message" } }

      before do
        3.times do
          instance = ManagedServiceInstance.make(:space => app.space)
          binding = ServiceBinding.make(:app => app, :service_instance => instance)
          app.add_service_binding(binding)
        end

        DeaClient.stub(:start_app_message).and_return(dea_start_message)
      end

      it "includes app guid, task id and download/upload uris" do
        blobstore_url_generator.stub(:app_package_download_url).with(app).and_return("http://www.app.uri")
        blobstore_url_generator.stub(:droplet_upload_url).with(app).and_return("http://www.droplet.upload.uri")
        blobstore_url_generator.stub(:buildpack_cache_download_url).with(app).and_return("http://www.buildpack.cache.download.uri")
        blobstore_url_generator.stub(:buildpack_cache_upload_url).with(app).and_return("http://www.buildpack.cache.upload.uri")
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
          request[:properties][:buildpack_git_url].should == "git://example.com/foo.git"
        end

        it "doesn't return a buildpack key" do
          app.buildpack = "git://example.com/foo.git"
          request = staging_task.staging_request
          expect(request[:properties]).to_not have_key(:buildpack_key)
        end
      end

      it "includes start app message" do
        request = staging_task.staging_request
        request[:start_message].should include dea_start_message
      end

      it "includes app index 0" do
        request = staging_task.staging_request
        request[:start_message].should include ({ :index => 0 })
      end

      it "overwrites droplet sha" do
        request = staging_task.staging_request
        request[:start_message].should include ({ :sha1 => nil })
      end

      it "overwrites droplet download uri" do
        request = staging_task.staging_request
        request[:start_message].should include ({ :executableUri => nil })
      end

      describe "the list of admin buildpacks" do
        before do
          VCAP::CloudController::Buildpack.should_receive(:list_admin_buildpacks).
            with(blobstore_url_generator).and_return("list of admins")
        end

        def self.it_includes_a_list_of_admin_buildpacks
          it "includes a list of admin buildpacks" do
            request = staging_task.staging_request
            expect(request[:admin_buildpacks]).to eql "list of admins"
          end
        end

        context "when a specific buildpack is not requested" do
          it_includes_a_list_of_admin_buildpacks
        end

        context "when a specific buildpack is requested" do
          before do
            buildpack = Buildpack.make()
            app.buildpack = buildpack.name
            app.save()
          end

          it_includes_a_list_of_admin_buildpacks
        end
      end

      it "includes the key of an admin buildpack when the app has a buildpack specified" do
        buildpack = Buildpack.make()
        app.buildpack = buildpack.name
        app.save()

        request = staging_task.staging_request
        expect(request[:properties][:buildpack_key]).to eql buildpack.key
      end

      it "doesn't include the custom buildpack url keys when the app has a buildpack specified" do
        buildpack = Buildpack.make()
        app.buildpack = buildpack.name
        app.save()

        request = staging_task.staging_request
        expect(request[:properties]).to_not have_key(:buildpack)
        expect(request[:properties]).to_not have_key(:buildpack_git_url)
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
