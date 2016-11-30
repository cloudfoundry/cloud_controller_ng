require 'spec_helper'
require 'cloud_controller/diego/docker/docker_uri_converter'

module VCAP::CloudController
  RSpec.describe DockerURIConverter do
    let(:converter) { described_class.new }

    context('and the docker image url has no host') do
      context('and image only') do
        let(:image_url) { 'image' }

        it 'prefix the path "docker" host and with "library/"' do
          expect(converter.convert(image_url)).to eq('docker:///library/image')
        end
      end

      context('and user/image') do
        let(:image_url) { 'user/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker:///user/image')
        end
      end

      context('and a image with tag') do
        let(:image_url) { 'image:tag' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker:///library/image#tag')
        end
      end

      context('and a user/image with tag') do
        let(:image_url) { 'user/image:tag' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker:///user/image#tag')
        end
      end
    end

    context('and the docker image url has host:port') do
      context('and image only') do
        let(:image_url) { '10.244.2.6:8080/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://10.244.2.6:8080/image')
        end
      end

      context('and a host with port (without a tld)') do
        let(:image_url) { 'foobar:8080/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://foobar:8080/image')
        end
      end

      context('and the host is localhost') do
        let(:image_url) { 'localhost/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://localhost/image')
        end
      end

      context('and user/image') do
        let(:image_url) { '10.244.2.6:8080/user/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://10.244.2.6:8080/user/image')
        end
      end

      context('and a image with tag') do
        let(:image_url) { '10.244.2.6:8080/image:tag' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://10.244.2.6:8080/image#tag')
        end
      end

      context('and a user/image with tag') do
        let(:image_url) { '10.244.2.6:8080/user/image:tag' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://10.244.2.6:8080/user/image#tag')
        end
      end
    end

    context('and the docker image url has host docker.io') do
      context('and image only') do
        let(:image_url) { 'docker.io/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://docker.io/library/image')
        end
      end

      context('and user/image') do
        let(:image_url) { 'docker.io/user/image' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://docker.io/user/image')
        end
      end

      context('and image with tag') do
        let(:image_url) { 'docker.io/image:tag' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://docker.io/library/image#tag')
        end
      end

      context('and a user/image with tag') do
        let(:image_url) { 'docker.io/user/image:tag' }

        it 'builds the correct rootFS path' do
          expect(converter.convert(image_url)).to eq('docker://docker.io/user/image#tag')
        end
      end
    end

    context('and the docker image url has scheme') do
      let(:image_url) { 'https://docker.io/repo' }
      it('errors') do
        expect {
          converter.convert image_url
        }.to raise_error(DockerURIConverter::InvalidDockerURI, 'Docker URI [https://docker.io/repo] should not contain scheme')
      end
    end
  end
end
