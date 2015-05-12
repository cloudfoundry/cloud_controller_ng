require 'spec_helper'

describe 'Broker API Versions' do
  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => '0df671d34c80f0d847eaa2974220794a',
      'broker_api_v2.1_spec.rb' => '4d031aeec862463e7a4b9d74702ac254',
      'broker_api_v2.2_spec.rb' => '29d240c39137cc654c1aeff6e0e2abf1',
      'broker_api_v2.3_spec.rb' => '784b3ca4f7afbac4428c55a37b82b7e4',
      'broker_api_v2.4_spec.rb' => '9be296cb6ce21259cafa15c9a6f06004',
      'broker_api_v2.5_spec.rb' => '5babf49a7cee063016bb6bc024b8d290',
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
