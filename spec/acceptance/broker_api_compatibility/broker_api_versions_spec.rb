require 'spec_helper'

describe 'Broker API Versions' do
  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => 'a49243c40c479a11a4a9e5b57d1df57f',
      'broker_api_v2.1_spec.rb' => '79cb09f2525a4006c8da0c6eb9ad9322',
      'broker_api_v2.2_spec.rb' => 'e2828295dd36f93462a537a7c0f5fd57',
      'broker_api_v2.3_spec.rb' => '4b1b24cc22887fc4ad8868359148f9df',
    }
  end

  it 'verifies that there is a broker API test for each minor version' do
    stub_request(:get, 'http://username:password@broker-url/v2/catalog').to_return do |request|
      @version = request.headers['X-Broker-Api-Version']
      { status: 200, body: {}.to_json }
    end

    post('/v2/service_brokers',
      { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
      json_headers(admin_headers))

    major_version, current_minor_version = @version.split('.').map(&:to_i)
    broker_api_specs = (0..current_minor_version).to_a.map do |minor_version|
      "broker_api_v#{major_version}.#{minor_version}_spec.rb"
    end

    expect(broker_api_specs.length).to be > 0

    current_directory = File.dirname(__FILE__)
    current_directory_list = Dir.entries(current_directory)

    actual_checksums = {}
    broker_api_specs.each do |spec|
      expect(current_directory_list).to include(spec)

      filename = "#{current_directory}/#{spec}"
      actual_checksums[spec] = Digest::MD5.hexdigest(File.read(filename))
    end


    # These tests are not meant to be changed since they help ensure backwards compatibility.
    # If you do need to update this test, you can update the expected sha
    expect(actual_checksums).to eq(spec_sha)
  end
end
