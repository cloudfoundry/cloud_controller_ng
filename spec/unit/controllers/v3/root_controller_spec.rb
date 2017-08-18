require 'rails_helper'

RSpec.describe RootController, type: :controller do
  describe '#v3_root' do
    it 'returns a link to self' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3"
      expect(hash['links']['self']['href']).to eq(expected_uri)
    end

    it 'returns a link to tasks' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/tasks"
      expect(hash['links']['tasks']['href']).to eq(expected_uri)
    end

    it 'returns a link to apps' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/apps"
      expect(hash['links']['apps']['href']).to eq(expected_uri)
    end

    it 'returns a link to builds' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/builds"
      expect(hash['links']['builds']['href']).to eq(expected_uri)
    end

    it 'returns a link to packages' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/packages"
      expect(hash['links']['packages']['href']).to eq(expected_uri)
    end

    it 'returns a link to isolation segments' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/isolation_segments"
      expect(hash['links']['isolation_segments']['href']).to eq(expected_uri)
    end

    it 'returns a link to organizations' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/organizations"
      expect(hash['links']['organizations']['href']).to eq(expected_uri)
    end

    it 'returns a link to spaces' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/spaces"
      expect(hash['links']['spaces']['href']).to eq(expected_uri)
    end

    it 'returns a link to processes' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/processes"
      expect(hash['links']['processes']['href']).to eq(expected_uri)
    end

    it 'returns a link to droplets' do
      get :v3_root
      hash = MultiJson.load(response.body)
      expected_uri = "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}/v3/droplets"
      expect(hash['links']['droplets']['href']).to eq(expected_uri)
    end
  end
end
