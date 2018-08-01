require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe IdempotentDirectory do
      let(:fog_directory) do
        double('Fog::**::Directory')
      end

      let(:directory) do
        double('Directory')
      end

      subject(:idempotent_directory) do
        IdempotentDirectory.new(directory)
      end

      describe '#get_or_create' do
        context 'when the directory exists' do
          it 'should return the existing Fog directory' do
            expect(directory).to receive(:get).and_return(fog_directory)
            expect(directory).not_to receive(:create)

            expect(idempotent_directory.get_or_create).to eq(fog_directory)
          end
        end

        context 'when the directory does not exist' do
          it 'should create and return a new Fog directory' do
            expect(directory).to receive(:get).and_return(nil)
            expect(directory).to receive(:create).and_return(fog_directory)

            expect(idempotent_directory.get_or_create).to eq(fog_directory)
          end
        end
      end
    end
  end
end
