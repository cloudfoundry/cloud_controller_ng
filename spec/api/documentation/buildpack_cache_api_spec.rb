require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Blobstores', type: :api do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:request_headers) { { 'AUTHORIZATION' => admin_auth_header } }
  let(:file) { File.expand_path('../../fixtures/good.zip', File.dirname(__FILE__)) }
  let(:key) { 'my-key' }
  let(:workspace) { Dir.mktmpdir }
  let(:cc_addr) { '1.2.3.4' }
  let(:cc_port) { 5678 }

  let(:blobstore_config) do
    {
      external_host: cc_addr,
      external_port: cc_port,
      droplets: {
        droplet_directory_key: 'cc-droplets',
        fog_connection: {
          provider: 'Local',
          local_root: Dir.mktmpdir('droplets', workspace)
        }
      },
      directories: {
        tmpdir: Dir.mktmpdir('tmpdir', workspace)
      },
      index: 99,
      name: 'api_z1'
    }
  end

  before do
    TestConfig.override(blobstore_config)
  end

  after do
    Fog.mock!
    FileUtils.rm_rf(workspace)
  end

  delete '/v2/blobstores/buildpack_cache' do
    example 'Delete all blobs in the Buildpack cache blobstore' do
      explanation <<-eos
        This endpoint will delete all of the existing buildpack caches in
        the blobstore. The buildpack cache is used during staging by buildpacks
        as a way to cache certain resources, e.g. downloaded Ruby gems. An admin
        who wanted to decrease the size of their blobstore could use this endpoint
        to delete unnecessary blobs.
      eos

      Fog.unmock!
      blobstore = CloudController::DependencyLocator.instance.buildpack_cache_blobstore
      blobstore.cp_to_blobstore(file, key)
      expect(blobstore.exists?(key)).to be_truthy

      client.delete '/v2/blobstores/buildpack_cache', {}, request_headers

      expect(status).to eq 201

      successes, failures = Delayed::Worker.new.work_off
      expect([successes, failures]).to eq [1, 0]

      expect(blobstore.exists?(key)).to be_falsey
    end
  end
end
