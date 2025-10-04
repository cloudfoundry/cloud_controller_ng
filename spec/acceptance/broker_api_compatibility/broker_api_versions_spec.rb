require 'spec_helper'

RSpec.describe 'Broker API Versions' do
  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => '75687923a86d85bcafe69dc03aad13ff',
      'broker_api_v2.1_spec.rb' => 'd2b36b0c028926a6cbf5164714b04545',
      'broker_api_v2.2_spec.rb' => '7a34a4d835efeb0d129da559133ba5fe',
      'broker_api_v2.3_spec.rb' => '569a61d79d7dee31cc78dd447799fd8b',
      'broker_api_v2.4_spec.rb' => '637fff704df656d47f4f0e75927d2003',
      'broker_api_v2.5_spec.rb' => '4cbc9df341ba86c2f1791b1a4870547c',
      'broker_api_v2.6_spec.rb' => 'a1608878f601819c90b44be5f317ec44',
      'broker_api_v2.7_spec.rb' => '2160e3d4985039f8fd2881106c7226ae',
      'broker_api_v2.8_spec.rb' => '4cf48cbdd3db911c2c3a648ecc0475b8',
      'broker_api_v2.9_spec.rb' => '002089c49e4c2db32689be56d48d4a45',
      'broker_api_v2.10_spec.rb' => '2668e6821e9b45ab6d7c7e9eca9deb68',
      'broker_api_v2.11_spec.rb' => '99e61dc50ceb635b09b3bd16901a4fa6',
      'broker_api_v2.12_spec.rb' => '6be5f9646bf885498dd88c090fbed7af',
      'broker_api_v2.13_spec.rb' => 'b8423b9f28e68adbc3c767b2185561c5',
      'broker_api_v2.14_spec.rb' => '73b5de4f83d280d959eb9844c19a3018',
      'broker_api_v2.15_spec.rb' => 'c8c910e903636d1a82e5a77fcdc1fbab'
    }
  end
  let(:digester) { Digester.new(algorithm: OpenSSL::Digest::MD5) }

  it 'verifies that there is a broker API test for each minor version' do
    stub_request(:get, 'http://broker-url/v2/catalog').
      with(basic_auth: %w[username password]).
      to_return do |request|
      @version = request.headers['X-Broker-Api-Version']
      { status: 200, body: {}.to_json }
    end

    post('/v2/service_brokers',
         { name: 'broker-name', broker_url: 'http://broker-url', auth_username: 'username', auth_password: 'password' }.to_json,
         admin_headers)

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
      actual_checksums[spec] = digester.digest(File.read(filename))
    end

    # These tests are not meant to be changed since they help ensure backwards compatibility.
    # If you do need to update this test, you can update the expected sha
    expect(actual_checksums).to eq(spec_sha)
  end
end
