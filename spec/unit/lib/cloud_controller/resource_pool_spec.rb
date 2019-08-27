require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ResourcePool do
    include_context 'resource pool'

    describe '#match_resources' do
      before do
        @resource_pool.add_directory(@tmpdir)
      end

      it 'calls match_resources on ResourceMatch object' do
        descriptors = @descriptors + [@nonexisting_descriptor]
        resource_match = ResourceMatch.new(descriptors)
        allow(ResourceMatch).to receive(:new).with(descriptors).and_return(resource_match)
        expect(resource_match).to receive(:match_resources).and_call_original
        res = @resource_pool.match_resources(descriptors)
        expect(res).to eq(@descriptors)
      end
    end

    describe '#resource_sizes' do
      it 'should return resources with sizes' do
        @resource_pool.add_directory(@tmpdir)

        without_sizes = @descriptors.map do |d|
          { 'sha1' => d['sha1'] }
        end

        res = @resource_pool.resource_sizes(without_sizes)
        expect(res).to eq(@descriptors)
      end
    end

    describe '#add_path' do
      it 'should walk the fs tree and add only allowable files' do
        expect(@resource_pool).to receive(:add_path).exactly(@total_allowed_files).times
        @resource_pool.add_directory(@tmpdir)
      end
    end

    describe '#size_allowed?' do
      before do
        @minimum_size = 5
        @maximum_size = 7
        @resource_pool.minimum_size = @minimum_size
        @resource_pool.maximum_size = @maximum_size
      end

      it 'should return true for a size between min and max size' do
        expect(@resource_pool.send(:size_allowed?, @minimum_size + 1)).to be true
      end

      it 'should return false for a size < min size' do
        expect(@resource_pool.send(:size_allowed?, @minimum_size - 1)).to be false
      end

      it 'should return false for a size > max size' do
        expect(@resource_pool.send(:size_allowed?, @maximum_size + 1)).to be false
      end

      it 'should return false for a nil size' do
        expect(@resource_pool.send(:size_allowed?, nil)).to be nil
      end
    end

    describe '#copy' do
      let(:descriptor) do
        { 'sha1' => 'deadbeef' }
      end

      before do
        allow(@resource_pool).to receive(:resource_known?).and_return(true)
      end

      it 'streams the resource to the destination' do
        expect(@resource_pool.blobstore).to receive(:download_from_blobstore).with(descriptor['sha1'], 'some/destination')

        @resource_pool.copy(descriptor, 'some/destination')
      end
    end
  end
end
