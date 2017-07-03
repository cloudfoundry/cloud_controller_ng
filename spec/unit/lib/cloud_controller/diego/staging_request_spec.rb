require 'spec_helper'
require 'cloud_controller/diego/staging_request'

module VCAP::CloudController::Diego
  RSpec.describe StagingRequest do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:process) do
      VCAP::CloudController::AppFactory.make(
        stack:            VCAP::CloudController::Stack.default,
        file_descriptors: 16384,
        memory:           1024,
        disk_quota:       1946,
      )
    end

    let(:staging_payload) do
      {
        app_id: process.guid,
        file_descriptors: 16384,
        memory_mb: 1024,
        disk_mb: 1946,
        environment: Environment.new(process).as_json,
        egress_rules: [],
        timeout: 1800,
        log_guid: process.guid,
        lifecycle: 'buildpack',
        lifecycle_data: {
          whatever: 'we want',
        },
        completion_callback: 'http://awesome.done/baller'
      }
    end

    let(:staging_request) do
      request = StagingRequest.new
      request.app_id = process.guid
      request.file_descriptors = 16384
      request.memory_mb = 1024
      request.disk_mb = 1946
      request.environment = Environment.new(process).as_json
      request.egress_rules = []
      request.timeout = 1800
      request.log_guid = process.guid
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
      let(:optional_keys) { [:lifecycle_data, :egress_rules, :isolation_segment] }

      context "when the app's space is not associated with an isolation segment" do
        it 'does not raise an error' do
          expect {
            staging_request.message
          }.to_not raise_error
        end

        it 'omits isolation_segment data from the message' do
          expect(staging_request.message.keys).to_not include(:isolation_segment)
        end
      end

      context "when the app's space is associated with an isolation segment" do
        before do
          staging_request.isolation_segment = 'segment-name'
        end

        it 'includes the isolation_segment name in the message' do
          expect(staging_request.message[:isolation_segment]).to eq('segment-name')
        end
      end

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
