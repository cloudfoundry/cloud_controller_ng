require 'lightweight_spec_helper'
require 'cloud_controller/blobstore/blob_key_generator'

module CloudController
  module Blobstore
    RSpec.describe BlobKeyGenerator do
      let(:subject) { BlobKeyGenerator }

      describe '#key_from_full_path' do
        let(:path) { 'ab/cd/some-guid' }

        it 'drops the first two directories and outputs the blobstore key' do
          key = subject.key_from_full_path(path)
          expect(key).to eq('some-guid')
        end
      end

      describe '#full_path_from_key' do
        let(:key) { 'some-guid' }

        it 'creates a blobstore file path from the key' do
          path = subject.full_path_from_key(key)
          expect(path).to eq('so/me/some-guid')
        end
      end
    end
  end
end
