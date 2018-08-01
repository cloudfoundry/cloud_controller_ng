require 'spec_helper'
require 'cloud_controller/blobstore/null_client'
require_relative 'client_shared'

module CloudController
  module Blobstore
    RSpec.describe NullClient do
      subject(:client) { NullClient.new }
      let(:deletable_blob) { instance_double(Blob) }

      it_behaves_like 'a blobstore client'
    end
  end
end
