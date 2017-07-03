require 'spec_helper'

RSpec.describe 'Broker API Versions' do
  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => '4b18861a044ec57709ff529557a656d3',
      'broker_api_v2.1_spec.rb' => 'd0559352542dda5cbd3f010cbdc622f2',
      'broker_api_v2.2_spec.rb' => '4fc472fc502b50aa7451b3e376823fe0',
      'broker_api_v2.3_spec.rb' => 'b226a2bcd068ba6db28dd4ea26a94cdb',
      'broker_api_v2.4_spec.rb' => '17ddf45ce44d07f8912f3a8031ae8016',
      'broker_api_v2.5_spec.rb' => 'a1c55e4193072955fa600197e07ac64a',
      'broker_api_v2.6_spec.rb' => '4c55e7de2295685022e580e49c2e8d5c',
      'broker_api_v2.7_spec.rb' => '6ac3a8f83f3bc2492715b42a8fecb2a0',
      'broker_api_v2.8_spec.rb' => '2b1b662b4874f5bac4481de7cf15b363',
      'broker_api_v2.9_spec.rb' => '9de8ebbdc0e2b60b791c6f7db4e1c8ee',
      'broker_api_v2.10_spec.rb' => '27e81c4c540e39a4e4eac70c8efb14ba',
      'broker_api_v2.11_spec.rb' => '99e61dc50ceb635b09b3bd16901a4fa6',
      'broker_api_v2.12_spec.rb' => 'b9626f09abf20d9d1d0e71ef1ac0df70',
    }
  end
  let(:digester) { Digester.new(algorithm: Digest::MD5) }

  it 'verifies that there is a broker API test for each minor version' do
    stub_request(:get, 'http://username:password@broker-url/v2/catalog').to_return do |request|
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
