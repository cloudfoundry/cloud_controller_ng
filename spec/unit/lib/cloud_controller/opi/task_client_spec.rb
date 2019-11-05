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

  subject(:client) { described_class.new(config) }

  describe 'can desire a task' do
    it 'should return nothing' do
      response = client.desire_task(nil, nil, nil)
      expect(response).to be_nil
    end

    it 'should not send any request to opi' do
      expect(a_request(:any, opi_url)).not_to have_been_made
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
    it 'should return nothing' do
      response = client.cancel_task(nil)
      expect(response).to be_nil
    end

    it 'should not send any request to opi' do
      expect(a_request(:any, opi_url)).not_to have_been_made
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
