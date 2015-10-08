require 'spec_helper'

module VCAP::CloudController
  describe AdminBuildpacksPresenter do
    let(:url_generator) { CloudController::DependencyLocator.instance.blobstore_url_generator }
    let(:blobstore) { CloudController::DependencyLocator.instance.buildpack_blobstore }

    subject { described_class.new(url_generator, blobstore) }

    def create_buildpack(key, position, file)
      blobstore.cp_to_blobstore(file, key)
      Buildpack.make(key: key, position: position)
    end

    describe '#to_staging_message_array' do
      context 'when there are no buildpacks' do
        it 'returns an empty array' do
          expect(subject.to_staging_message_array).to eq([])
        end
      end

      context 'when there are buildpacks' do
        include TempFileCreator

        let(:file) { temp_file_with_content }

        before do
          create_buildpack('third-buildpack', 3, file)
          create_buildpack('first-buildpack', 1, file)
          create_buildpack('second-buildpack', 2, file)
        end

        it 'returns the buildpacks as an ordered array of hashes' do
          allow(url_generator).to receive(:admin_buildpack_blob_download_url).and_return('a-url')
          expect(subject.to_staging_message_array).to eq([
            { key: 'first-buildpack', url: 'a-url' },
            { key: 'second-buildpack', url: 'a-url' },
            { key: 'third-buildpack', url: 'a-url' },
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

        context 'when there is no url' do
          before do
            Buildpack.make(key: 'no-url', position: 5)
          end

          it 'does not include them' do
            expect(subject.to_staging_message_array).not_to include(include(key: 'no-url'))
          end
        end

        context 'caching' do
          after do
            Fog::Time.now = Time.now
          end

          it 'generates new urls' do
            first = subject.to_staging_message_array

            Fog::Time.now = Time.now + 60
            second = subject.to_staging_message_array

            expect(first).to_not eq(second)
          end

          context 'with the same buildpacks' do
            it 'does not call the blobstore' do
              subject.to_staging_message_array

              expect(blobstore).not_to receive(:blob)
              subject.to_staging_message_array
            end
          end

          context 'with buildpack changes' do
            before do
              subject.to_staging_message_array

              buildpacks = Buildpack.list_admin_buildpacks
              buildpacks[0].delete
              buildpacks[1].key = 'updated-second-buildpack'
              @updated_buildpack = buildpacks[1].save
              blobstore.cp_to_blobstore(file, 'updated-second-buildpack')
              @new_buildpack = create_buildpack('new-first-buildpack', 1, file)
            end

            it 'generates urls for any change' do
              allow(url_generator).to receive(:admin_buildpack_blob_download_url).and_return('a-url')

              expect(blobstore).to receive(:blob).with(@new_buildpack.key).ordered.and_call_original
              expect(blobstore).to receive(:blob).with(@updated_buildpack.key).ordered.and_call_original
              expect(subject.to_staging_message_array).to eq([
                { key: 'new-first-buildpack', url: 'a-url' },
                { key: 'updated-second-buildpack', url: 'a-url' },
                { key: 'third-buildpack', url: 'a-url' },
              ])
            end
          end
        end
      end
    end
  end
end
