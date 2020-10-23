require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ResourceMatch do
    include_context 'resource pool'

    describe '#match_resources' do
      before do
        @resource_pool.add_directory(@tmpdir)
      end

      it 'should return an empty list when no resources match' do
        res = ResourceMatch.new([@nonexisting_descriptor]).match_resources
        expect(res).to eq([])
      end

      it 'should return a resource that matches' do
        res = ResourceMatch.new([@descriptors.first, @nonexisting_descriptor]).match_resources
        expect(res).to eq([@descriptors.first])
      end

      it 'should return many resources that match' do
        res = ResourceMatch.new(@descriptors + [@nonexisting_descriptor]).match_resources
        expect(res).to eq(@descriptors)
      end

      it 'does not break when the sha1 is not long enough to generate a key' do
        expect do
          ResourceMatch.new([{ 'sha1' => 0, 'size' => 123 }]).match_resources
          ResourceMatch.new([{ 'sha1' => 'abc', 'size' => 234 }]).match_resources
        end.not_to raise_error
      end

      describe 'logging' do
        let(:maximum_file_size) { 500.megabytes } # this is arbitrary
        let(:minimum_file_size) { 3.kilobytes }
        let(:descriptors) do
          [
            { 'sha1' => 0, 'size' => 500 },
            { 'sha1' => 1, 'size' => 1024 },
            { 'sha1' => 2, 'size' => 10_011 },
            { 'sha1' => 3, 'size' => 50_011 },
            { 'sha1' => 4, 'size' => 90_011 },
            { 'sha1' => 5, 'size' => 11_100_000 },
            { 'sha1' => 6, 'size' => 22_200_000 },
            { 'sha1' => 7, 'size' => 32_200_000 },
            { 'sha1' => 8, 'size' => 1_110_000_000 },
          ]
        end

        it 'logs prior to matching all resources' do
          ResourceMatch.new(descriptors).match_resources
        end

        it 'correctly calculates and logs the time for each file size range' do
          Timecop.freeze
          allow(ResourcePool.instance).to receive(:resource_known?) do
            Timecop.freeze(2.seconds.from_now)
            true
          end
          expect(Steno.logger('cc.resource_pool')).to receive(:info).once.with('starting resource matching', {
            total_resources_to_match: 6,
            resource_count_by_size: {
              '1KB or less': 0,
              '1KB to 100KB': 3,
              '100KB to 1MB': 0,
              '1MB to 100MB': 3,
              '100MB to 1GB': 0,
              '1GB or more': 0,
            }
          })

          expect(Steno.logger('cc.resource_pool')).to receive(:info).once.with('done matching resources', {
            total_resources_to_match: 6,
            total_resource_match_time: '12.0 seconds',
            resource_count_by_size: {
              '1KB or less': 0,
              '1KB to 100KB': 3,
              '100KB to 1MB': 0,
              '1MB to 100MB': 3,
              '100MB to 1GB': 0,
              '1GB or more': 0,
            },
            resource_match_time_by_size: {
              '1KB or less': '0.0 seconds',
              '1KB to 100KB': '6.0 seconds',
              '100KB to 1MB': '0.0 seconds',
              '1MB to 100MB': '6.0 seconds',
              '100MB to 1GB': '0.0 seconds',
              '1GB or more': '0.0 seconds',
            }
          })
          ResourceMatch.new(descriptors).match_resources
        end
      end
    end

    describe '#resource_count_by_filesize' do
      let(:maximum_file_size) { 500.megabytes } # this is arbitrary
      let(:minimum_file_size) { 3.kilobytes }

      let(:descriptors) do
        [
          { 'sha1' => 0, 'size' => 500 },
          { 'sha1' => 1, 'size' => 1024 },
          { 'sha1' => 2, 'size' => 10_011 },
          { 'sha1' => 3, 'size' => 50_011 },
          { 'sha1' => 4, 'size' => 90_011 },
          { 'sha1' => 5, 'size' => 11_100_000 },
          { 'sha1' => 6, 'size' => 22_200_000 },
          { 'sha1' => 7, 'size' => 32_200_000 },
          { 'sha1' => 8, 'size' => 1_110_000_000 },
        ]
      end

      it 'correctly calculates the quantity of each file size range' do
        histogram = ResourceMatch.new(descriptors).resource_count_by_filesize
        # Filters out descriptors outside of range
        expected_histogram = {
          '1KB or less':  0,
          '1KB to 100KB': 3,
          '100KB to 1MB': 0,
          '1MB to 100MB': 3,
          '100MB to 1GB': 0,
          '1GB or more':  0,
        }
        expect(histogram).to eq(expected_histogram)
      end
    end
  end
end
