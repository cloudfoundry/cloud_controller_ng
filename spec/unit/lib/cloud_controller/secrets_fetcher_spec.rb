require 'spec_helper'
require 'cloud_controller/secrets_fetcher'

module VCAP::CloudController
  RSpec.describe SecretsFetcher do
    describe '.fetch_secrets_from_file' do
      let(:secrets_file) do
        file = Tempfile.new('secrets_file.yml')
        file.write(YAML.dump({ 'one' => secret_value_file.path, 'nested' => { 'two' => secret_value_file.path } }))
        file.close
        file
      end
      let(:secret_value_file) do
        file = Tempfile.new('secret_value_file')
        file.write('some-password')
        file.close
        file
      end

      subject(:fetched_secrets) { SecretsFetcher.fetch_secrets_from_file(secrets_file.path) }

      context 'when all files referenced in the secrets file exist' do
        it 'return a hash containing the values of the secrets referenced in the secrets file' do
          expect(fetched_secrets).to eq({ 'one' => 'some-password', 'nested' => { 'two' => 'some-password' } })
        end
      end

      context 'when one of the files referenced in the secret file does not exist' do
        let(:secrets_file) do
          file = Tempfile.new('secrets_file.yml')
          file.write(YAML.dump({ 'one' => secret_value_file.path, 'nested' => { 'two' => '/path/does/not/exist' } }))
          file.close
          file
        end

        it 'raises an error' do
          expect { fetched_secrets }.to raise_error(%r(unable to read secret value file: "/path/does/not/exist"))
        end
      end
    end
  end
end
