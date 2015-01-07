require 'spec_helper'

module VCAP::CloudController
  describe AdminBuildpacksPresenter do
    let(:url_generator) { double(:url_generator) }

    subject { described_class.new(url_generator) }

    before do
      allow(url_generator).to receive(:admin_buildpack_download_url) do |bp|
        "http://blobstore/#{bp.key}"
      end
    end

    describe '#to_staging_message_array' do
      context 'when there are no buildpacks' do
        it 'returns an empty array' do
          expect(subject.to_staging_message_array).to eq([])
        end
      end

      context 'when there are buildpacks' do
        before do
          Buildpack.make(key: 'third-buildpack', position: 3)
          Buildpack.make(key: 'first-buildpack', position: 1)
          Buildpack.make(key: 'second-buildpack', position: 2)
        end

        it 'returns the buildpacks as an ordered array of hashes' do
          expect(subject.to_staging_message_array).to eq([
            { key: 'first-buildpack', url: 'http://blobstore/first-buildpack' },
            { key: 'second-buildpack', url: 'http://blobstore/second-buildpack' },
            { key: 'third-buildpack', url: 'http://blobstore/third-buildpack' },
          ])
        end

        context 'when there are disabled buildpacks' do
          before do
            Buildpack.make(key: 'disabled', enabled: false)
          end

          it 'does not include them' do
            expect(subject.to_staging_message_array).not_to include(include(key: 'disabled'))
          end
        end
      end
    end
  end
end
