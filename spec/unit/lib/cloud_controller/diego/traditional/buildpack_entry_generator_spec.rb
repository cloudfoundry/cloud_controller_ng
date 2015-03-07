require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Traditional
      describe BuildpackEntryGenerator do
        subject(:buildpack_entry_generator) { BuildpackEntryGenerator.new(blobstore_url_generator) }
        let(:app) { AppFactory.make(command: '/a/custom/command') }

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
          context 'when the app has a CustomBuildpack' do
            context 'when the CustomBuildpack uri ends with .zip' do
              before do
                app.buildpack = 'http://example.com/mybuildpack.zip'
              end

              it "should use the CustomBuildpack's uri and name it 'custom', and use the url as the key" do
                expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                  { name: 'custom', key: 'http://example.com/mybuildpack.zip', url: 'http://example.com/mybuildpack.zip', skip_detect: true }
                ])
              end
            end

            context 'when the CustomBuildpack uri does not end with .zip' do
              before do
                app.buildpack = 'http://example.com/mybuildpack'
              end

              it "should use the CustomBuildpack's uri and name it 'custom', and use the url as the key" do
                expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                  { name: 'custom', key: 'http://example.com/mybuildpack', url: 'http://example.com/mybuildpack', skip_detect: true }
                ])
              end
            end
          end

          context 'when the app has a named buildpack' do
            before do
              app.buildpack = 'java'
            end

            it 'should use that buildpack' do
              expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                { name: 'java', key: 'java-buildpack-key', url: admin_buildpack_download_url, skip_detect: true }
              ])
            end
          end

          context 'when the app has no buildpack specified' do
            it 'should use the list of admin buildpacks' do
              expect(buildpack_entry_generator.buildpack_entries(app)).to eq([
                { name: 'java', key: 'java-buildpack-key', url: admin_buildpack_download_url },
                { name: 'ruby', key: 'ruby-buildpack-key', url: admin_buildpack_download_url },
              ])
            end
          end

          context 'when an invalid buildpack type is returned for some reason' do
            it 'fails fast with a clear error' do
              allow(app).to receive(:buildpack).and_return(double('BazaarBuildpack'))
              expect { buildpack_entry_generator.buildpack_entries(app) }.to raise_error /Unsupported buildpack type/
            end
          end
        end
      end
    end
  end
end
