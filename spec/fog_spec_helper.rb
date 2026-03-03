# Use this helper for specs that need Fog/blobstore functionality with
# a clean state between tests (upload, download, delete operations).
#
# This helper resets Fog mocks and recreates buckets before each test.
#
# For specs that don't need blobstore isolation, use spec_helper instead.

require 'spec_helper'

RSpec.configure do |config|
  config.before(:each, :fog_isolation) do
    Fog::Mock.reset

    if Fog.mock?
      CloudController::DependencyLocator.instance.droplet_blobstore.ensure_bucket_exists
      CloudController::DependencyLocator.instance.package_blobstore.ensure_bucket_exists
      CloudController::DependencyLocator.instance.global_app_bits_cache.ensure_bucket_exists
      CloudController::DependencyLocator.instance.buildpack_blobstore.ensure_bucket_exists
    end
  end
end
