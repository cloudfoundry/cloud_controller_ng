require 'spec_helper'

describe 'Broker API Versions' do

  let(:spec_sha) do
    {
      'broker_api_v2.0_spec.rb' => '91b6ae0b65904497e256d5e8e9e6cd2e',
      'broker_api_v2.1_spec.rb' => '5c602d2de2fbed65e70c59ace3b282ac',
      'broker_api_v2.2_spec.rb' => 'feccf18486a72d6ef80230197ce206ca',
      'broker_api_v2.3_spec.rb' => '1f8346b886868031842e5ca410fd5a84',
      'broker_api_v2.4_spec.rb' => 'asdf',
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

    broker_api_specs.each do |spec|
      expect(current_directory_list).to include(spec)

      filename = "#{current_directory}/#{spec}"
      actual_checksum = Digest::MD5.hexdigest(File.read(filename))

      expect(actual_checksum).to eq(spec_sha[spec]), <<-MESSAGE.gsub(/\s+/,' ')
        You have made changes to the Service Broker API compatibility test: #{spec}. These tests are not meant to be
        changed since they help ensure backwards compatibility. If you do need to update this test, you can update the
        expected sha to #{actual_checksum}.
      MESSAGE
    end
  end
end

