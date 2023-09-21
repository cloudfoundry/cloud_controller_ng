require 'spec_helper'

RSpec.describe 'Broker API Versions' do
  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => 'd66f65205d508b5616c9a90e0e0ea239',
      'broker_api_v2.1_spec.rb' => '678ef57a165363ec23c78978ff527f2b',
      'broker_api_v2.2_spec.rb' => '4071fe54c267509fd4ed8424780e0cb2',
      'broker_api_v2.3_spec.rb' => 'dcf9872794e7e40bebc1f9dec64c38d8',
      'broker_api_v2.4_spec.rb' => '637fff704df656d47f4f0e75927d2003',
      'broker_api_v2.5_spec.rb' => 'efc346680280b2f7bb8c5d2443fed810',
      'broker_api_v2.6_spec.rb' => 'a1608878f601819c90b44be5f317ec44',
      'broker_api_v2.7_spec.rb' => '2160e3d4985039f8fd2881106c7226ae',
      'broker_api_v2.8_spec.rb' => '2b1b662b4874f5bac4481de7cf15b363',
      'broker_api_v2.9_spec.rb' => '4be645db7e7834a608441f48783d8dd5',
      'broker_api_v2.10_spec.rb' => 'e863a3e544dc50b4eca5d72440bba09b',
      'broker_api_v2.11_spec.rb' => '99e61dc50ceb635b09b3bd16901a4fa6',
      'broker_api_v2.12_spec.rb' => '1b6b1e41b72430362fcd74a0dff91b41',
      'broker_api_v2.13_spec.rb' => 'a06d3a177694bd67d9d8100d90984f6b',
      'broker_api_v2.14_spec.rb' => 'e774279c6e5e7cfb28b413e33ae85893',
      'broker_api_v2.15_spec.rb' => '24c8da3aa2f23053643d0c3969a69ee2'
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
