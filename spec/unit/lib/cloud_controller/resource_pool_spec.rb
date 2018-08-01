require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ResourcePool do
    include_context 'resource pool'

    describe '#match_resources' do
      before do
        @resource_pool.add_directory(@tmpdir)
      end

      it 'should return an empty list when no resources match' do
        res = @resource_pool.match_resources([@dummy_descriptor])
        expect(res).to eq([])
      end

      it 'should return a resource that matches' do
        res = @resource_pool.match_resources([@descriptors.first, @dummy_descriptor])
        expect(res).to eq([@descriptors.first])
      end

      it 'should return many resources that match' do
        res = @resource_pool.match_resources(@descriptors + [@dummy_descriptor])
        expect(res).to eq(@descriptors)
      end

      it 'does not break when the sha1 is not long enough to generate a key' do
        expect do
          @resource_pool.match_resources(['sha1' => 0, 'size' => 123])
          @resource_pool.match_resources(['sha1' => 'abc', 'size' => 234])
        end.not_to raise_error
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
