require 'spec_helper'
require 'cloud_controller/blobstore/url_generator/upload_url_generator'

module CloudController
  module Blobstore
    RSpec.describe UploadUrlGenerator do
      let(:blobstore_host) do
        'api.example.com'
      end
      let(:external_port) { 9292 }
      let(:tls_port) { 9293 }
      let(:connection_options) do
        {
          blobstore_host: blobstore_host,
          blobstore_external_port: external_port,
          blobstore_tls_port: tls_port,
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
        it 'gives out url for buildpack cache' do
          app_guid = Sham.guid
          stack    = Sham.name
          uri      = URI.parse(url_generator.buildpack_cache_upload_url(app_guid, stack))
          expect(uri.scheme).to eql 'http'
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql external_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/v3/buildpack_cache/#{stack}/#{app_guid}/upload"
        end

        it 'gives out url for droplet' do
          droplet_guid = Sham.guid
          uri          = URI.parse(url_generator.droplet_upload_url(droplet_guid))
          expect(uri.scheme).to eql 'http'
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql external_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/v3/droplets/#{droplet_guid}/upload"
        end

        describe 'when mtls is enabled for the cc_uploader' do
          before do
            connection_options[:mtls] = true
          end

          it 'gives out the mTLS url for droplet upload' do
            droplet_guid = Sham.guid
            uri          = URI.parse(url_generator.droplet_upload_url(droplet_guid))
            expect(uri.scheme).to eql 'https'
            expect(uri.host).to eql blobstore_host
            expect(uri.port).to eql tls_port
            expect(uri.path).to eql "/internal/v4/droplets/#{droplet_guid}/upload"
          end

          it 'gives out the mTLS url for buildpack_cache upload' do
            app_guid = Sham.guid
            stack    = Sham.name
            uri      = URI.parse(url_generator.buildpack_cache_upload_url(app_guid, stack))
            expect(uri.scheme).to eql 'https'
            expect(uri.host).to eql blobstore_host
            expect(uri.port).to eql tls_port
            expect(uri.path).to eql "/internal/v4/buildpack_cache/#{stack}/#{app_guid}/upload"
          end
        end
      end
    end
  end
end
