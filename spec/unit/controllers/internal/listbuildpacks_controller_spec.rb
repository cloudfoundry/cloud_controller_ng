require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ListBuildpacksController do
    let(:blobstore) { CloudController::DependencyLocator.instance.buildpack_blobstore }

    let(:url) { '/internal/buildpacks' }

    def create_buildpack(key, position, file)
      blobstore.cp_to_blobstore(file, key)
      Buildpack.make(key: key, position: position)
    end

    before do
      @internal_user = 'internal_user'
      @internal_password = 'internal_password'
      authorize @internal_user, @internal_password
    end

    describe 'authentication' do
      context 'when missing authentication' do
        it 'fails with authentication required' do
          header('Authorization', nil)
          get url
          expect(last_response.status).to eq(401)
        end
      end

      context 'when using invalid credentials' do
        it 'fails with authenticatiom required' do
          authorize 'bar', 'foo'
          get url
          expect(last_response.status).to eq(401)
        end
      end

      context 'when using valid credentials' do
        it 'succeeds' do
          get url
          expect(last_response.status).to eq(200)
        end
      end
    end

    context 'with a set of buildpacks' do
      include TempFileCreator

      let(:file) { temp_file_with_content }

      before do
        create_buildpack('third-buildpack', 3, file)
        create_buildpack('first-buildpack', 1, file)
        create_buildpack('second-buildpack', 2, file)
      end

      it 'returns all the buildpacks' do
        get url
        buildpacks = decoded_response

        expect(last_response.status).to eq(200)
        expect(buildpacks).to have(3).items
        buildpacks.each { |b| expect(b).to include('key', 'url') }
        expect(buildpacks.collect { |b| b['key'] }).to eq(['first-buildpack', 'second-buildpack', 'third-buildpack'])
      end
    end
  end
end
