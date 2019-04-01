require 'spec_helper'
require 'cloud_controller/blobstore/null_blob'
require_relative 'blob_shared'

module CloudController
  module Blobstore
    RSpec.describe NullBlob do
      subject(:blob) { NullBlob.new }

      it_behaves_like 'a blob'
    end
  end
end
