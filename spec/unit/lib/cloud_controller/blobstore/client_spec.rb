require 'lightweight_spec_helper'
require 'find'
require 'tempfile'
require 'securerandom'
require 'cloud_controller/blobstore/client'
require 'cloud_controller/blobstore/null_client'
require 'cloud_controller/blobstore/blob'
require_relative 'client_shared'

module CloudController
  module Blobstore
    RSpec.describe Client do
      subject(:client) { Client.new(NullClient.new) }
      let(:deletable_blob) { Blob.new }

      it_behaves_like 'a blobstore client'
    end
  end
end
