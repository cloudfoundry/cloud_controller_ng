require 'spec_helper'
require_relative '../blob_shared'

module CloudController
  module Blobstore
    RSpec.describe FogBlob do
      subject(:blob) do
        described_class.new(file, cdn)
      end
      let(:attrs) { { 'a' => 'b', 'c' => 'd' } }
      let(:file) { double('file', key: 'abcdef', attributes: attrs, destroy: nil) }
      let(:cdn) { double(:cdn, download_uri: 'http://localhost') }

      it_behaves_like 'a blob'

      describe '#internal_download_url' do
        context 'it is backed by a CDN' do
          let(:url_from_cdn) { 'http://some_distribution.cloudfront.net/ab/cd/abcdef' }

          before do
            allow(cdn).to receive(:download_uri).and_return(url_from_cdn)
          end

          it 'returns a url to the cdn' do
            expect(blob.internal_download_url).to eql(url_from_cdn)
          end
        end

        context 'when is not backed by a CDN' do
          let(:cdn) { nil }

          context 'a file responds to url' do
            before do
              allow(file).to receive(:url).and_return('http://example.com')
            end

            it 'returns a url from file' do
              expect(blob.internal_download_url).to eql('http://example.com')
            end

            it 'is valid for an hour' do
              Timecop.freeze do
                now = Time.now.utc
                expect(file).to receive(:url).with(now + 3600)
                blob.internal_download_url
              end
            end
          end

          context 'a file does not respond to url' do
            before do
              allow(file).to receive(:url).and_return(nil)
              allow(file).to receive(:public_url).and_return('http://example.com/public')
              it 'returns a public url from file' do
                expect(blob.internal_download_url).to eql('http://example.com/public')
              end
            end
          end
        end
      end

      describe '#public_download_url' do
        context 'it is backed by a CDN' do
          let(:url_from_cdn) { 'http://some_distribution.cloudfront.net/ab/cd/abcdef' }

          before do
            allow(cdn).to receive(:download_uri).and_return(url_from_cdn)
          end

          it 'returns a url to the cdn' do
            expect(blob.public_download_url).to eql(url_from_cdn)
          end
        end

        context 'when is not backed by a CDN' do
          let(:cdn) { nil }

          context 'a file responds to url' do
            before do
              allow(file).to receive(:url).and_return('http://example.com')
            end

            it 'returns a url from file' do
              expect(blob.public_download_url).to eql('http://example.com')
            end

            it 'is valid for an hour' do
              Timecop.freeze do
                now = Time.now.utc
                expect(file).to receive(:url).with(now + 3600)
                blob.public_download_url
              end
            end
          end

          context 'a file does not respond to url' do
            before do
              allow(file).to receive(:url).and_return(nil)
              allow(file).to receive(:public_url).and_return('http://example.com/public')
              it 'returns a public url from file' do
                expect(blob.public_download_url).to eql('http://example.com/public')
              end
            end
          end
        end
      end

      describe 'local_path' do
        it 'comes path of the file' do
          expect(file).to receive(:path).and_return('path')
          expect(blob.local_path).to eql('path')
        end
      end

      describe 'attributes' do
        it "returns the blob's attributes" do
          expect(blob.attributes).to eq(attrs)
        end

        it 'returns attributes for a set of keys' do
          expect(blob.attributes('c')).to eq({ 'c' => 'd' })
        end
      end
    end
  end
end
