require "spec_helper"

module VCAP::CloudController
  describe DiegoStagerTask do
    FakeLogger = Struct.new(:log_messages) do
      def info(message, _)
        log_messages << message
      end
    end

    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:staging_timeout) { 360 }
    let(:environment_json) { {} }
    let(:app) do
      AppFactory.make(:package_hash  => "abc",
                      :name => "app-name",
                      :droplet_hash  => "I DO NOTHING",
                      :package_state => "PENDING",
                      :state         => "STARTED",
                      :instances     => 1,
                      :memory => 259,
                      :disk_quota => 799,
                      :file_descriptors => 1234,
                      :environment_json => environment_json
      )
    end
    let(:blobstore_url_generator) { CloudController::DependencyLocator.instance.blobstore_url_generator }
    let(:completion_callback) { lambda {|x| return x } }

    before do
      EM.stub(:add_timer)
      EM.stub(:defer).and_yield
    end

    let(:diego_stager_task) { DiegoStagerTask.new(staging_timeout, message_bus, app, blobstore_url_generator) }

    describe '#stage' do
      let(:logger) { FakeLogger.new([]) }

      before do
        Steno.stub(:logger).and_return(logger)
      end

      def perform_stage
        diego_stager_task.stage(&completion_callback)
      end

      it 'assigns a new staging_task_id to the app being staged' do
        perform_stage
        app.staging_task_id.should_not be_nil
        app.staging_task_id.should == diego_stager_task.task_id
      end

      it 'logs the beginning of staging' do
        logger.should_receive(:info).with('staging.begin', { app_guid: app.guid })
        perform_stage
      end

      it 'publishes the diego.staging.start message' do
        perform_stage
        expect(message_bus.published_messages.first).
            to include(subject: "diego.staging.start", message: diego_stager_task.staging_request)
      end

      it 'the diego.staging.start message includes a stack' do
        perform_stage
        expect(message_bus.published_messages.first[:message]).
            to include(
                   stack: app.stack.name
               )
      end

      context 'when staging finishes' do
        before do
          message_bus.stub(:request).and_yield(response, 'I am an ignored inbox parameter')
        end

        context 'when the staging successfully completes' do
          let(:response) { {'task_log' => double(:task_log), 'detected_buildpack' => 'INTERCAL'} }

          it 'logs the staging result' do

            perform_stage
            logger.log_messages.include?("diego.staging.response")
          end

          it 'should update the app with the detected buildpack' do
            perform_stage
            app.detected_buildpack.should == 'INTERCAL'
          end

          it 'should call the completion callback' do
            completion_callback.should_receive(:call)
            perform_stage
          end

          context 'when another staging task has started' do
            before do
              app.stub(:staging_task_id).and_return('another-task-id')
            end

            it 'should not update the app with a detected buildpack' do
              perform_stage
              app.detected_buildpack.should_not == 'INTERCAL'
            end

            it 'should not call the completion callback' do
              completion_callback.should_not_receive(:call)
              perform_stage
            end
          end
        end

        context 'when the staging fails' do
          let(:response) { {"error" => "Sumpin' bad happened"} }

          before do
            message_bus.stub(:request).and_yield(response, nil)
          end

          it 'should mark the app as "failed to stage"' do
            app.should_receive(:mark_as_failed_to_stage)
            perform_stage
          end

          it 'should emit a loggregator error' do
            Loggregator.should_receive(:emit_error).with(app.guid, /bad/)
            perform_stage
          end

          it 'should not update the app with the detected buildpack' do
            perform_stage
            app.detected_buildpack.should_not == 'INTERCAL'
          end

          it 'should not call the completion callback' do
            completion_callback.should_not_receive(:call)
            perform_stage
          end

        end

        context 'when there is a message bus timeout' do
          let(:response) { {"timeout" => true} }

          it 'should mark the app as "failed to stage"' do
            app.should_receive(:mark_as_failed_to_stage)
            perform_stage
          end

          it 'should emit a loggregator error' do
            Loggregator.should_receive(:emit_error).with(app.guid, /timed out/)
            perform_stage
          end

          it 'should not update the app with the detected buildpack' do
            perform_stage
            app.detected_buildpack.should_not == 'INTERCAL'
          end

          it 'should not call the completion callback' do
            completion_callback.should_not_receive(:call)
            perform_stage
          end
        end
      end
    end

    describe "staging_request" do
      let(:environment_json) {  { "USER_DEFINED" => "OK" } }
      let(:domain) {  PrivateDomain.make :owning_organization => app.space.organization }
      let(:route) { Route.make(:domain => domain, :space => app.space) }

      let(:service_instance_one) do
        service = Service.make(:label => "elephant-label", :requires => ["syslog_drain"])
        service_plan = ServicePlan.make(:service => service)
        ManagedServiceInstance.make(:space => app.space, :service_plan => service_plan, :name => "elephant-name")
      end

      let(:service_instance_two) do
        service = Service.make(:label => "giraffesql-label")
        service_plan = ServicePlan.make(:service => service)
        ManagedServiceInstance.make(:space => app.space, :service_plan => service_plan, :name => "giraffesql-name")
      end

      let!(:service_binding_one) do
        ServiceBinding.make(:app => app, :service_instance => service_instance_one, :syslog_drain_url => "syslog_drain_url-syslog-url")
      end

      let!(:service_binding_two) do
        ServiceBinding.make(
            :app => app,
            :service_instance => service_instance_two,
            :credentials => {"uri" => "mysql://giraffes.rock"})
      end

      before do
        app.add_route(route)
      end

      describe "limits" do
        it "limits memory" do
          expect(diego_stager_task.staging_request[:memory_mb]).to eq(259)
        end
        it "limits disk" do
          expect(diego_stager_task.staging_request[:disk_mb]).to eq(799)
        end
        it "limits file descriptors" do
          expect(diego_stager_task.staging_request[:file_descriptors]).to eq(1234)
        end
      end

      describe "environment" do
        it "contains user defined environment variables" do
          expect(diego_stager_task.staging_request[:environment].last).to eq(["USER_DEFINED","OK"])
        end

        it "contains VCAP_APPLICATION from application" do
          expect(app.vcap_application).to be
          expect(
            diego_stager_task.staging_request[:environment]
          ).to include(["VCAP_APPLICATION", app.vcap_application.to_json])
        end

        it "contains VCAP_SERVICES" do
          elephant_label = service_instance_one.service.label + "-" + service_instance_one.service.version
          giraffe_label = service_instance_two.service.label + "-" + service_instance_two.service.version
          expected_hash = {
            elephant_label => [{
              "name" => service_instance_one.name,
              "label" => elephant_label,
              "tags" => service_instance_one.tags,
              "plan" => service_instance_one.service_plan.name,
              "credentials" => service_binding_one.credentials,
              "syslog_drain_url" => "syslog_drain_url-syslog-url"
            }],

            giraffe_label => [{
              "name" => service_instance_two.name,
              "label" => giraffe_label,
              "tags" => service_instance_two.tags,
              "plan" => service_instance_two.service_plan.name,
              "credentials" => service_binding_two.credentials,
            }]
          }
          expect(
            diego_stager_task.staging_request[:environment]
          ).to include(["VCAP_SERVICES", expected_hash.to_json])
        end

        it "contains DATABASE_URL" do
          expect(
            diego_stager_task.staging_request[:environment]
          ).to include(["DATABASE_URL", "mysql2://giraffes.rock"])
        end

        it "contains MEMORY_LIMIT" do
          expect(
            diego_stager_task.staging_request[:environment]
          ).to include(["MEMORY_LIMIT", "259m"])
        end

        it "contains app build artifact cache download uri" do
          blobstore_url_generator.should_receive(:buildpack_cache_download_url).with(app).and_return("http://buildpack-cache-download.uri")
          blobstore_url_generator.should_receive(:buildpack_cache_upload_url).with(app).and_return("http://buildpack-cache-upload.uri")
          staging_request = diego_stager_task.staging_request
          expect(staging_request[:build_artifacts_cache_download_uri]).to eq("http://buildpack-cache-download.uri")
          expect(staging_request[:build_artifacts_cache_upload_uri]).to eq("http://buildpack-cache-upload.uri")
        end

        it "contains app bits download uri" do
          blobstore_url_generator.should_receive(:app_package_download_url).with(app).and_return("http:/app-bits-download.uri")
          expect(diego_stager_task.staging_request[:app_bits_download_uri]).to eq("http:/app-bits-download.uri")
        end
      end
    end
  end
end
