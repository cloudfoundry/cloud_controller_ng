# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require File.expand_path("../support/mock_nats", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::AppStager do
    before { configure }

    let(:mock_nats) { NatsClientMock.new({}) }
    before { MessageBus.instance.nats.client = mock_nats }

    let(:mock_redis) { mock(:mock_redis).as_null_object }
    before { AppStager.configure({}, nil, mock_redis) }

    describe ".stage_app (stages sync/async)" do
      context "when the app package hash is nil" do
        let(:app) { Models::App.make(:package_hash => nil) }

        it "raises" do
          expect { AppStager.stage_app(app) { empty_block = true } }.to raise_error(VCAP::CloudController::Errors::AppPackageInvalid)
        end
      end

      context "when the app package hash is blank" do
        let(:app) { Models::App.make(:package_hash => "") }

        it "raises" do
          expect { AppStager.stage_app(app) { empty_block = true } }.to raise_error(VCAP::CloudController::Errors::AppPackageInvalid)
        end
      end

      context "when the app package is valid" do
        let(:app) { Models::App.make(:package_hash => "abc") }
        before { app.staged?.should be_false }

        let(:upload_handle) do
          LegacyStaging::DropletUploadHandle.new(app.guid).tap do |h|
            h.upload_path = Tempfile.new("tmp_droplet")
          end
        end

        before { LegacyStaging.should_receive(:create_handle).and_return(upload_handle) }

        def self.it_requests_staging(options={})
          it "requests staging (sends NATS request)" do
            data_in_request = nil
            mock_nats.subscribe("staging") do |data, _|
              data_in_request = data
            end

            with_em_and_thread { stage }

            task = AppStagerTask.new(nil, nil, nil, app)
            expected_data = task.staging_request(options[:async])
            data_in_request.should == JSON.dump(expected_data)
          end
        end

        def self.it_completes_staging
          context "when no other staging has happened" do
            it "stages the app" do
              expect {
                with_em_and_thread { stage }
              }.to change {
                [app.staged?, app.needs_staging?]
              }.from([false, true]).to([true, false])
            end

            it "stores droplet" do
              expect {
                with_em_and_thread { stage }
              }.to change { LegacyStaging.droplet_exists?(app.guid) }.from(false).to(true)
            end

            it "updates droplet hash on the app" do
              expect {
                with_em_and_thread { stage }
              }.to change { app.droplet_hash }.from(nil)
            end

            it "removes upload handle" do
              LegacyStaging.should_receive(:destroy_handle)
              with_em_and_thread { stage }
            end

            it "saves off staging log for short time" do
              mock_redis.should_receive(:set).with(StagingTaskLog.key_for_id(app.guid), "task-log")
              with_em_and_thread { stage }
            end

            it "calls provided callback" do
              callback_called = false
              with_em_and_thread { stage { callback_called = true } }
              callback_called.should be_true
            end
          end

          context "when other staging has happened" do
            before do
              @before_staging_completion = -> {
                app.droplet_hash = "droplet-hash"
                app.package_state = "PENDING"
                app.save
              }
            end

            it "raises a StagingError" do
              expect {
                with_em_and_thread { stage }
              }.to raise_error(
                     Errors::StagingError,
                     /failed to stage because app changed while staging/
                   )
            end

            it "does not stage the app" do
              expect {
                ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
              }.to_not change {
                [app.staged?, app.needs_staging?]
              }.from([false, true])
            end

            it "does not store droplet" do
              expect {
                ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
              }.to_not change { LegacyStaging.droplet_exists?(app.guid) }.from(false)
            end

            it "does not update droplet hash on the app" do
              expect {
                ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
              }.to_not change {
                app.refresh
                app.droplet_hash
              }.from("droplet-hash")
            end

            it "removes upload handle" do
              LegacyStaging.should_receive(:destroy_handle)
              ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
            end

            it "does not save off staging log for short time" do
              mock_redis.should_not_receive(:set)
              ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
            end

            it "does not call provided callback" do
              callback_called = false
              ignore_error(Errors::StagingError) do
                with_em_and_thread do
                  stage { callback_called = true }
                end
              end
              callback_called.should be_false
            end
          end
        end

        def self.it_raises_staging_error
          it "raises a StagingError" do
            expect {
              with_em_and_thread { stage }
            }.to raise_error(Errors::StagingError, /failed to stage/)
          end

          it "removes upload handle" do
            LegacyStaging.should_receive(:destroy_handle)
            ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
          end
        end

        def self.it_logs_staging_error
          it "logs StagingError instead of raising to avoid stopping main runloop" do
            logger = mock(:logger, :info => nil)
            logger.should_receive(:error) do |msg|
              msg.should match /failed to stage/
            end

            Steno.stub(:logger => logger)
            with_em_and_thread { stage }
          end

          it "removes upload handle" do
            LegacyStaging.should_receive(:destroy_handle)
            with_em_and_thread { stage }
          end
        end

        def self.it_does_not_complete_staging
          it "keeps the app as not staged" do
            expect {
              ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
            }.to_not change { app.staged? }.from(false)
          end

          it "does not store droplet" do
            expect {
              ignore_error(Errors::StagingError) { with_em_and_thread { stage } }
            }.to_not change { LegacyStaging.droplet_exists?(app.guid) }.from(false)
          end

          it "does not call provided callback (not yet)" do
            callback_called = false
            ignore_error(Errors::StagingError) do
              with_em_and_thread { stage { callback_called = true } }
            end
            callback_called.should be_false
          end
        end

        describe "staging synchronously and stager returning sync staging response" do
          describe "receiving staging completion message" do
            def stage(&blk)
              stub_schedule_sync do
                @before_staging_completion.call if @before_staging_completion
                reply_with_staging_completion
              end
              AppStager.stage_app(app, &blk)
            end

            context "when staging succeeds" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => nil,
                })
              end

              it "does not returns streaming log url in response" do
                with_em_and_thread { stage.streaming_log_url.should be_nil }
              end

              it_requests_staging
              it_completes_staging
            end

            context "when staging fails without a reason" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", nil, :invalid_json => true)
              end

              it_raises_staging_error
              it_does_not_complete_staging
            end

            context "when staging returned an error response" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => "staging failed",
                })
              end

              it_raises_staging_error
              it_does_not_complete_staging
            end
          end
        end

        describe "staging asynchronously and stager returning async staging responses" do
          describe "receiving staging setup completion message" do
            def stage(&blk)
              stub_schedule_sync do
                @before_staging_completion.call if @before_staging_completion
                reply_with_staging_setup_completion
              end
              response = AppStager.stage_app(app, :async => true, &blk)
              EM.stop # explicitly
              response
            end

            context "when staging setup succeeds" do
              def reply_with_staging_setup_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => "task-streaming-log-url",
                  "error" => nil,
                })
              end

              it "returns streaming log url and rest will happen asynchronously" do
                with_em_and_thread { stage.streaming_log_url.should == "task-streaming-log-url" }
              end

              it_requests_staging :async => true
              it_does_not_complete_staging
            end

            context "when staging setup fails without a reason" do
              def reply_with_staging_setup_completion
                mock_nats.reply_to_last_request("staging", nil, :invalid_json => true)
              end

              it_raises_staging_error
              it_does_not_complete_staging
            end

            context "when staging setup returned an error response" do
              def reply_with_staging_setup_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => "staging failed",
                })
              end

              it_raises_staging_error
              it_does_not_complete_staging
            end
          end

          describe "receiving staging completion message" do
            def stage(&blk)
              stub_schedule_sync do
                @before_staging_completion.call if @before_staging_completion
                reply_with_staging_setup_completion
              end
              AppStager.stage_app(app, :async => true, &blk)
              reply_with_staging_completion
            end

            def reply_with_staging_setup_completion
              mock_nats.reply_to_last_request("staging", {
                "task_id" => "task-id",
                "task_log" => "task-log",
                "task_streaming_log_url" => "task-streaming-log-url",
                "error" => nil,
              })
            end

            context "when app staging succeeds" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => nil,
                })
              end

              it_completes_staging
            end

            context "when app staging fails without a reason" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", nil, :invalid_json => true)
              end

              it_logs_staging_error
              it_does_not_complete_staging
            end

            context "when app staging returned an error response" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => "staging failed",
                })
              end

              it_logs_staging_error
              it_does_not_complete_staging
            end
          end
        end

        describe "staging asynchronously and stager returning sync staging response" do
          describe "receiving staging completion message" do
            def stage(&blk)
              stub_schedule_sync do
                @before_staging_completion.call if @before_staging_completion
                reply_with_staging_completion
              end
              AppStager.stage_app(app, :async => true, &blk)
            end

            context "when staging succeeds" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => nil,
                })
              end

              it "does not returns streaming log url in response" do
                with_em_and_thread { stage.streaming_log_url.should be_nil }
              end

              it_requests_staging :async => true
              it_completes_staging
            end

            context "when staging fails without a reason" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", nil, :invalid_json => true)
              end

              it_raises_staging_error
              it_does_not_complete_staging
            end

            context "when staging returned an error response" do
              def reply_with_staging_completion
                mock_nats.reply_to_last_request("staging", {
                  "task_id" => "task-id",
                  "task_log" => "task-log",
                  "task_streaming_log_url" => nil,
                  "error" => "staging failed",
                })
              end

              it_raises_staging_error
              it_does_not_complete_staging
            end
          end
        end
      end
    end

    describe ".staging_request" do
      before(:all) { @app = Models::App.make }

      before(:all) do
        3.times do
          instance = Models::ServiceInstance.make(:space => @app.space)
          binding = Models::ServiceBinding.make(:app => @app, :service_instance => instance)
          @app.add_service_binding(binding)
        end
      end

      def request(async=false)
        AppStagerTask.new(nil, nil, nil, @app).staging_request(async)
      end

      def store_app_package(app)
        # When Fog is in local mode it looks at the filesystem
        tmpdir = Dir.mktmpdir
        zipname = File.join(tmpdir, "test.zip")
        create_zip(zipname, 1, 1)
        AppPackage.to_zip(app.guid, [], File.new(zipname))
        FileUtils.rm_rf(tmpdir)
      end

      it "includes app guid and download/upload uris" do
        store_app_package(@app)
        request.tap do |r|
          r[:app_id].should == @app.guid
          r[:download_uri].should match /^http/
          r[:upload_uri].should match /^http/
        end
      end

      it "includes async flag" do
        request(false)[:async].should == false
        request(true)[:async].should == true
      end

      it "includes misc app properties" do
        request.tap do |r|
          r[:properties][:meta].should be_kind_of(Hash)
          r[:properties][:runtime_info].should be_kind_of(Hash)
          r[:properties][:runtime_info].should have_key(:name)
          r[:properties][:framework_info].should be_kind_of(Hash)
        end
      end

      it "includes service binding properties" do
        r = request
        r[:properties][:services].count.should == 3
        r[:properties][:services].each do |s|
          s[:credentials].should be_kind_of(Hash)
          s[:options].should be_kind_of(Hash)
        end
      end

      context "when app does not have buildpack" do
        it "returns nil for buildpack" do
          @app.buildpack = nil
          r = request
          r[:properties][:buildpack].should be_nil
        end
      end

      context "when app has a buildpack" do
        it "returns url for buildpack" do
          @app.buildpack = "git://example.com/foo.git"
          r = request
          r[:properties][:buildpack].should == "git://example.com/foo.git"
        end
      end
    end

    describe ".delete_droplet" do
      before { AppStager.unstub(:delete_droplet) }
      let(:app) { Models::App.make }

      it "should do nothing if the droplet does not exist" do
        guid = Sham.guid
        LegacyStaging.droplet_exists?(guid).should == false
        AppStager.delete_droplet(app)
        LegacyStaging.droplet_exists?(guid).should == false
      end

      it "should delete the droplet if it exists" do
        droplet = Tempfile.new(app.guid)
        droplet.write("droplet contents")
        droplet.close
        LegacyStaging.store_droplet(app.guid, droplet.path)

        LegacyStaging.droplet_exists?(app.guid).should == true
        AppStager.delete_droplet(app)
        LegacyStaging.droplet_exists?(app.guid).should == false
      end
    end
  end

  def stub_schedule_sync(&before_resolve)
    EM.stub(:schedule_sync) do |&blk|
      promise = VCAP::Concurrency::Promise.new

      EM.schedule do
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
      end

      promise.resolve
    end
  end

  def ignore_error(error_class)
    yield
  rescue error_class
  end
end
