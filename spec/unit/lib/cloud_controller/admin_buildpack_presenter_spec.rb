require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AdminBuildpacksPresenter do
    let(:url_generator) { double(:url_generator) }

    subject { described_class }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:blobstore_url_generator) { url_generator }
      allow(url_generator).to receive(:admin_buildpack_download_url) do |bp|
        "http://blobstore/#{bp.key}"
      end
    end

    describe '.enabled_buildpacks' do
      context 'when there are no buildpacks' do
        it 'returns an empty array' do
          expect(subject.enabled_buildpacks).to eq([])
        end
      end

      context 'when there are buildpacks' do
        before do
          Buildpack.make(key: 'third-buildpack', position: 3)
          Buildpack.make(key: 'first-buildpack', position: 1)
          Buildpack.make(key: 'second-buildpack', position: 2)
        end

        it 'returns the buildpacks as an ordered array of hashes' do
          expect(subject.enabled_buildpacks).to eq([
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
            expect(subject.enabled_buildpacks).not_to include(include(key: 'disabled'))
          end
        end
      end
    end
  end
end
