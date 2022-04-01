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

    RSpec.describe '#Azure_branch_merge' do
      it_should_be_removed(
        by: '2022/5/1',
        explanation: 'It\'s been ~3 months since we made this PR https://github.com/Azure/azure-storage-ruby/pull/212. '\
        'If its not already been accepted its time for a new solution. '\
        'See https://docs.google.com/document/d/1s4-64mDqif31K5hkCJf6QW86rad2hYV7W17AqZyHhWE/edit#heading=h.nnrp172sw8k1 for more context',
      )
    end
  end
end
