require 'spec_helper'
require 'cloud_controller/blobstore/url_generator/upload_url_generator'

module CloudController
  module Blobstore
    RSpec.describe UploadUrlGenerator do
      let(:blobstore_host) do
        'api.example.com'
      end
      let(:blobstore_port) do
        9292
      end
      let(:connection_options) do
        {
          blobstore_host: blobstore_host,
          blobstore_port: blobstore_port,
          user:           username,
          password:       password,
        }
      end

      let(:username) { 'username' }
      let(:password) { 'password' }

      subject(:url_generator) do
        described_class.new(connection_options)
      end

      context 'uploads' do
        it 'gives out url for droplets' do
          app = VCAP::CloudController::AppFactory.make
          uri = URI.parse(url_generator.droplet_upload_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/droplets/#{app.guid}/upload"
        end

        it 'gives out url for buildpack cache' do
          app = VCAP::CloudController::AppFactory.make
          uri = URI.parse(url_generator.buildpack_cache_upload_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/buildpack_cache/#{app.guid}/upload"
        end

        it 'gives out url for app buildpack cache' do
          app_guid = Sham.guid
          stack    = Sham.name
          uri      = URI.parse(url_generator.v3_app_buildpack_cache_upload_url(app_guid, stack))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/v3/buildpack_cache/#{stack}/#{app_guid}/upload"
        end

        it 'gives out url for package droplet' do
          droplet_guid = Sham.guid
          uri          = URI.parse(url_generator.package_droplet_upload_url(droplet_guid))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/v3/droplets/#{droplet_guid}/upload"
        end
      end
    end
  end
end
