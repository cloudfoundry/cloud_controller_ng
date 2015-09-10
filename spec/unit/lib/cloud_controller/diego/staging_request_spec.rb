require 'spec_helper'
require 'cloud_controller/diego/staging_request'

module VCAP::CloudController::Diego
  describe StagingRequest do
    let(:app) do
      a = VCAP::CloudController::App.make
      a.staging_task_id = 'staging-task-id'
      a.stack = VCAP::CloudController::Stack.default
      a.file_descriptors = 16384
      a.memory = 1024
      a.disk_quota = 4096
      a
    end

    let(:staging_payload) do
      {
        app_id: app.guid,
        file_descriptors: app.file_descriptors,
        memory_mb: app.memory,
        disk_mb: app.disk_quota,
        environment: Environment.new(app).as_json,
        egress_rules: [],
        timeout: 1800,
        log_guid: app.guid,
        lifecycle: 'buildpack',
        lifecycle_data: {
          whatever: 'we want',
        },
        completion_callback: 'http://awesome.done/baller'
      }
    end

    let(:staging_request) do
      request = StagingRequest.new
      request.app_id = app.guid
      request.file_descriptors = app.file_descriptors
      request.memory_mb = app.memory
      request.disk_mb = app.disk_quota
      request.environment = Environment.new(app).as_json
      request.egress_rules = []
      request.timeout = 1800
      request.log_guid = app.guid
      request.lifecycle = 'buildpack'
      request.lifecycle_data = {
        whatever: 'we want',
      }
      request.completion_callback = 'http://awesome.done/baller'
      request
    end

    it 'populates the fields' do
      expect(staging_request.message).to eq(staging_payload)
    end

    describe 'validation' do
      let(:optional_keys) { [:lifecycle_data, :egress_rules] }

      context 'when lifecycle data is missing' do
        before do
          staging_request.lifecycle_data = nil
        end

        it 'does not raise an error' do
          expect {
            staging_request.message
          }.to_not raise_error
        end

        it 'omits lifecycle data from the message' do
          expect(staging_request.message.keys).to_not include(:lifecycle_data)
        end
      end

      context 'when egress_rules is missing' do
        before do
          staging_request.egress_rules = nil
        end

        it 'does not raise an error' do
          expect {
            staging_request.message
          }.to_not raise_error
        end

        it 'omits lifecycle data from the message' do
          expect(staging_request.message.keys).to_not include(:egress_rules)
        end
      end

      context 'when anything else is missing' do
        let(:required_keys) { staging_payload.keys - optional_keys }

        it 'fails with a schema validation error' do
          required_keys.each do |key|
            req = staging_request.clone
            req.public_send("#{key}=", nil)
            expect {
              req.message
            }.to raise_error(Membrane::SchemaValidationError)
          end
        end
      end
    end
  end
end
