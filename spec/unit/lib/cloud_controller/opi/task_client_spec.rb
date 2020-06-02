# require 'support/bootstrap/test_config'
require 'spec_helper'
require 'cloud_controller/opi/task_client'

RSpec.describe(OPI::TaskClient) do
  let(:opi_url) { 'http://opi.service.cf.internal:8077' }
  let(:config) do
    TestConfig.override(
      opi: {
        url: opi_url
      },
    )
  end
  let(:task_completion_callback_generator) { instance_double(VCAP::CloudController::Diego::TaskCompletionCallbackGenerator) }
  let(:environment_collector) { class_double(VCAP::CloudController::Diego::TaskEnvironmentVariableCollector) }
  let(:environment) { [{ name: 'FOO', value: 'BAR' }] }

  subject(:client) { described_class.new(config, environment_collector) }

  describe 'can desire a buildpack task' do
    let(:task) {
      instance_double(
        VCAP::CloudController::TaskModel,
        guid: 'GUID',
        name: 'NAME',
        command: 'COMMAND',
        app: double(guid: 'APP_GUID', name: 'APP_NAME'),
        droplet: double(
          lifecycle_type: VCAP::CloudController::Lifecycles::BUILDPACK,
          droplet_hash: 'DROPLET_HASH',
          guid: 'DROPLET_GUID'
        ),
        space: double(
          guid: 'SPACE_GUID',
          name: 'SPACE_NAME',
          organization: double(guid: 'ORG_GUID', name: 'ORG_NAME')
        )
      )
    }

    before(:each) do
      allow(VCAP::CloudController::Diego::TaskCompletionCallbackGenerator).to receive(:new).and_return(task_completion_callback_generator)
      allow(environment_collector).to receive(:for_task).with(task).and_return(environment)
      allow(task_completion_callback_generator).to receive(:generate).with(task).and_return('CALLBACK')
      stub_request(:post, "#{opi_url}/tasks/GUID").to_return(status: 202)
    end

    it 'posts the task to the http client' do
      client.desire_task(task, 'some-domain')

      expect(WebMock).to have_requested(:post, "#{opi_url}/tasks/GUID").with(body: {
        name: 'NAME',
        app_guid: 'APP_GUID',
        app_name: 'APP_NAME',
        org_guid: 'ORG_GUID',
        org_name: 'ORG_NAME',
        space_guid: 'SPACE_GUID',
        space_name: 'SPACE_NAME',
        environment: [{ name: 'FOO', value: 'BAR' }],
        completion_callback: 'CALLBACK',
        lifecycle: {
          buildpack_lifecycle: {
            droplet_hash: 'DROPLET_HASH',
            droplet_guid: 'DROPLET_GUID',
            start_command: 'COMMAND'
          }
        }
      }.to_json)
    end

    context 'the http client returns an error' do
      before(:each) do
        stub_request(:post, "#{opi_url}/tasks/GUID").to_return(status: 500, body: '{}')
      end

      it 'raises an API error' do
        expect {
          client.desire_task(task, 'some-domain')
        }.to raise_error(CloudController::Errors::ApiError) do |e|
          expect(e.name).to eq('RunnerError')
        end
      end
    end
  end

  describe 'can desire a docker task' do
    let(:task) {
      instance_double(
        VCAP::CloudController::TaskModel,
        guid: 'GUID',
        name: 'NAME',
        command: 'COMMAND',
        app: double(guid: 'APP_GUID', name: 'APP_NAME'),
        droplet: double(
          lifecycle_type: VCAP::CloudController::Lifecycles::DOCKER,
          docker_receipt_image: 'ORG/IMAGE',
          docker_receipt_username: 'USERNAME',
          docker_receipt_password: 'PASSWORD'
        ),
        space: double(
          guid: 'SPACE_GUID',
          name: 'SPACE_NAME',
          organization: double(guid: 'ORG_GUID', name: 'ORG_NAME')
        )
      )
    }

    before(:each) do
      allow(VCAP::CloudController::Diego::TaskCompletionCallbackGenerator).to receive(:new).and_return(task_completion_callback_generator)
      allow(environment_collector).to receive(:for_task).with(task).and_return(environment)
      allow(task_completion_callback_generator).to receive(:generate).with(task).and_return('CALLBACK')
      stub_request(:post, "#{opi_url}/tasks/GUID").to_return(status: 202)
    end

    it 'posts the task to the http client' do
      client.desire_task(task, 'some-domain')

      expect(WebMock).to have_requested(:post, "#{opi_url}/tasks/GUID").with(body: {
        name: 'NAME',
        app_guid: 'APP_GUID',
        app_name: 'APP_NAME',
        org_guid: 'ORG_GUID',
        org_name: 'ORG_NAME',
        space_guid: 'SPACE_GUID',
        space_name: 'SPACE_NAME',
        environment: [{ name: 'FOO', value: 'BAR' }],
        completion_callback: 'CALLBACK',
        lifecycle: {
          docker_lifecycle: {
            image: 'ORG/IMAGE',
            command: ['/bin/sh', '-c', 'COMMAND'],
            registry_username: 'USERNAME',
            registry_password: 'PASSWORD'
          }
        }
      }.to_json)
    end
  end

  describe 'can fetch a task' do
    it 'should return a empty dummy task' do
      task = client.fetch_task('some-guid')
      expect(task).to eq(Diego::Bbs::Models::Task.new)
    end

    it 'should not send any request to opi' do
      expect(a_request(:any, opi_url)).not_to have_been_made
    end
  end

  describe 'can fetch all tasks' do
    it 'should return an empty list' do
      tasks = client.fetch_tasks
      expect(tasks).to be_empty
    end

    it 'should not send any request to opi' do
      expect(a_request(:any, opi_url)).not_to have_been_made
    end
  end

  describe 'can cancel a task' do
    before(:each) do
      stub_request(:delete, "#{opi_url}/tasks/the-task-guid").to_return(status: 200, body: '{}')
    end
    it 'requests task deletion from opi ' do
      client.cancel_task('the-task-guid')

      expect(WebMock).to have_requested(:delete, "#{opi_url}/tasks/the-task-guid")
    end

    context 'when the task does not exist' do
      before(:each) do
        stub_request(:delete, "#{opi_url}/tasks/the-task-guid").to_return(status: 404, body: '{}')
      end

      it 'ignores the error' do
        expect {
          client.cancel_task('the-task-guid')
        }.not_to raise_error
      end
    end

    context 'when the task deletion fails' do
      before(:each) do
        stub_request(:delete, "#{opi_url}/tasks/the-task-guid").to_return(status: 500, body: '{"message": "i-failed"}')
      end

      it 'raises an ApiError' do
        expect {
          client.cancel_task('the-task-guid')
        }.to raise_error(CloudController::Errors::ApiError) do |e|
          expect(e.name).to eq('TaskError')
        end
      end
    end
  end

  describe 'can bump freshness' do
    it 'should return nothing' do
      response = client.bump_freshness
      expect(response).to be_nil
    end

    it 'should not send any request to opi' do
      expect(a_request(:any, opi_url)).not_to have_been_made
    end
  end
end
