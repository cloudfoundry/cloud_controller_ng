require 'spec_helper'
require 'cloud_controller/blobstore/null_client'
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
