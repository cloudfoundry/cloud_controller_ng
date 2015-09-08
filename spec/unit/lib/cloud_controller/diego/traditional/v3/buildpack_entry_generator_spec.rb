require 'spec_helper'
require 'cloud_controller/diego/traditional/v3/buildpack_entry_generator'

module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        describe BuildpackEntryGenerator do
          subject(:buildpack_entry_generator) { BuildpackEntryGenerator.new(blobstore_url_generator) }

          let(:admin_buildpack_download_url) { 'http://admin-buildpack.example.com' }
          let(:app_package_download_url) { 'http://app-package.example.com' }
          let(:build_artifacts_cache_download_uri) { 'http://buildpack-artifacts-cache.example.com' }

          let(:blobstore_url_generator) { double('fake url generator') }

          before do
            Buildpack.create(name: 'java', key: 'java-buildpack-key', position: 1)
            Buildpack.create(name: 'ruby', key: 'ruby-buildpack-key', position: 2)

            allow(blobstore_url_generator).to receive(:app_package_download_url).and_return(app_package_download_url)
            allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return(admin_buildpack_download_url)
            allow(blobstore_url_generator).to receive(:buildpack_cache_download_url).and_return(build_artifacts_cache_download_uri)

            allow(EM).to receive(:add_timer)
            allow(EM).to receive(:defer).and_yield
          end

          describe '#buildpack_entries' do
            let(:v3_app) { AppModel.make }
            let(:package) { PackageModel.make(app_guid: v3_app.guid) }
            let(:buildpack_info) { BuildpackRequestValidator.new({ buildpack: buildpack }) }

            before { buildpack_info.valid? }

            context 'when the user has specified a custom buildpack' do
              context 'when the buildpack_uri ends with .zip' do
                let(:buildpack) { 'http://example.com/my_buildpack_url.zip' }

                it "should use the buildpack_uri and name it 'custom', and use the url as the key" do
                  expect(buildpack_entry_generator.buildpack_entries(buildpack_info)).to eq([
                    { name: 'custom', key: 'http://example.com/my_buildpack_url.zip', url: 'http://example.com/my_buildpack_url.zip', skip_detect: true }
                  ])
                end
              end

              context 'when the buildpack_uri does not end with .zip' do
                let(:buildpack) { 'http://example.com/my_buildpack_url' }

                it "should use the buildpack_uri and name it 'custom', and use the url as the key" do
                  expect(buildpack_entry_generator.buildpack_entries(buildpack_info)).to eq([
                    { name: 'custom', key: 'http://example.com/my_buildpack_url', url: 'http://example.com/my_buildpack_url', skip_detect: true }
                  ])
                end
              end
            end

            context 'when the package has a named buildpack' do
              let(:buildpack) { 'java' }

              it 'should use that buildpack' do
                expect(buildpack_entry_generator.buildpack_entries(buildpack_info)).to eq([
                  { name: 'java', key: 'java-buildpack-key', url: admin_buildpack_download_url, skip_detect: true }
                ])
              end
            end

            context 'when the user has not specified a buildpack' do
              let(:buildpack) { nil }

              it 'should use the list of admin buildpacks' do
                expect(buildpack_entry_generator.buildpack_entries(buildpack_info)).to eq([
                  { name: 'java', key: 'java-buildpack-key', url: admin_buildpack_download_url },
                  { name: 'ruby', key: 'ruby-buildpack-key', url: admin_buildpack_download_url },
                ])
              end
            end

            context 'when an invalid buildpack type is returned for some reason' do
              let(:buildpack) { '???' }

              it 'fails fast with a clear error' do
                expect { buildpack_entry_generator.buildpack_entries(buildpack_info) }.to raise_error /Unsupported buildpack type/
              end
            end
          end
        end
      end
    end
  end
end
