# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Resumable upload" do

      before :all do
        @endpoint = 'oss-cn-hangzhou.aliyuncs.com'
        @bucket_name = 'rubysdk-bucket'
        @object_key = 'resumable_file'
        @bucket = Client.new(
          :endpoint => @endpoint,
          :access_key_id => 'xxx',
          :access_key_secret => 'yyy').get_bucket(@bucket_name)

        @file = './file_to_upload'
        # write 100B data
        File.open(@file, 'w') do |f|
          (1..10).each do |i|
            f.puts i.to_s.rjust(9, '0')
          end
        end
      end

      before :each do
        File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      end

      def object_url
        "#{@bucket_name}.#{@endpoint}/#{@object_key}"
      end

      def parse_query_from_uri(uri)
        query = {}
        str = uri.to_s[uri.to_s.index('?')+1..-1]
        str.split("&").each do |q|
          v = q.split('=')
          query[v.at(0)] = v.at(1)
        end

        query
      end

      def mock_txn_id(txn_id)
        Nokogiri::XML::Builder.new do |xml|
          xml.InitiateMultipartUploadResult {
            xml.Bucket @bucket
            xml.Key @object
            xml.UploadId txn_id
          }
        end.to_xml
      end

      def mock_error(code, message)
        Nokogiri::XML::Builder.new do |xml|
          xml.Error {
            xml.Code code
            xml.Message message
            xml.RequestId '0000'
          }
        end.to_xml
      end

      def err(msg, reqid = '0000')
        "#{msg} RequestId: #{reqid}"
      end

      it "should upload file when all goes well" do
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))
        stub_request(:put, /#{object_url}\?partNumber.*/)
        stub_request(:post, /#{object_url}\?uploadId.*/)

        prg = []
        @bucket.resumable_upload(
          @object_key, @file, :part_size => 10) { |p| prg << p }

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(1)

        part_numbers = Set.new([])
        upload_ids = Set.new([])

        expect(WebMock).to have_requested(
          :put, /#{object_url}\?partNumber.*/).with{ |req|
          query = parse_query_from_uri(req.uri)
          part_numbers << query['partNumber']
          upload_ids << query['uploadId']
        }.times(10)

        expect(part_numbers.to_a).to match_array((1..10).map{ |x| x.to_s })
        expect(upload_ids.to_a).to match_array(['upload_id'])

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploadId.*/).times(1)

        expect(File.exist?("#{@file}.cpt")).to be false
        expect(prg.size).to eq(10)
      end

      it "should upload file with callback" do
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))
        stub_request(:put, /#{object_url}\?partNumber.*/)
        stub_request(:post, /#{object_url}\?uploadId.*/)

        callback = Callback.new(
          url: 'http://app.server.com/callback',
          query: {'id' => 1, 'name' => '杭州'},
          body: 'hello world',
          host: 'server.com'
        )
        @bucket.resumable_upload(
          @object_key, @file, part_size: 10, callback: callback)

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(1)

        expect(WebMock).to have_requested(
                             :put, /#{object_url}\?partNumber.*/)
                            .times(10)
        expect(WebMock)
          .to have_requested(
                :post, /#{object_url}\?uploadId.*/)
               .with { |req| req.headers.key?('X-Oss-Callback') }
               .times(1)

        expect(File.exist?("#{@file}.cpt")).to be false
      end

      it "should raise CallbackError when callback failed" do
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))
        stub_request(:put, /#{object_url}\?partNumber.*/)

        code = 'CallbackFailed'
        message = 'Error status: 502.'
        stub_request(:post, /#{object_url}\?uploadId.*/)
          .to_return(:status => 203, :body => mock_error(code, message))

        callback = Callback.new(
          url: 'http://app.server.com/callback',
          query: {'id' => 1, 'name' => '杭州'},
          body: 'hello world',
          host: 'server.com'
        )
        expect {
          @bucket.resumable_upload(
            @object_key, @file, part_size: 10, callback: callback)
        }.to raise_error(CallbackError, err(message))

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(1)

        expect(WebMock).to have_requested(
                             :put, /#{object_url}\?partNumber.*/)
                            .times(10)

        expect(WebMock)
          .to have_requested(
                :post, /#{object_url}\?uploadId.*/)
               .with { |req| req.headers.key?('X-Oss-Callback') }
               .times(1)

        expect(File.exist?("#{@file}.cpt")).to be true
      end

      it "should upload file with custom headers" do
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))
        stub_request(:put, /#{object_url}\?partNumber.*/)
        stub_request(:post, /#{object_url}\?uploadId.*/)

        @bucket.resumable_upload(
          @object_key, @file,
          part_size: 10,
          headers: {'cache-CONTROL' => 'cacheit', 'CONTENT-disposition' => 'oh;yeah'})

        headers = {}
        expect(WebMock).to have_requested(
                             :post, /#{object_url}\?uploads.*/)
                           .with { |req| headers = req.headers }.times(1)

        expect(headers['Cache-Control']).to eq('cacheit')
        expect(headers['Content-Disposition']).to eq('oh;yeah')
        expect(File.exist?("#{@file}.cpt")).to be false
      end

      it "should restart when begin txn fails" do
        code = 'Timeout'
        message = 'Request timeout.'

        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:status => 500, :body => mock_error(code, message)).then
          .to_return(:body => mock_txn_id('upload_id'))
        stub_request(:put, /#{object_url}\?partNumber.*/)
        stub_request(:post, /#{object_url}\?uploadId.*/)

        success = false
        2.times do
          begin
            @bucket.resumable_upload(@object_key, @file, :part_size => 10)
            success = true
          rescue
            # pass
          end
        end

        expect(success).to be true
        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(2)
        expect(WebMock).to have_requested(
          :put, /#{object_url}\?partNumber.*/).times(10)
        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploadId.*/).times(1)
      end

      it "should resume when upload part fails" do
        # begin multipart
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))

        # commit multipart
        stub_request(:post, /#{object_url}\?uploadId.*/)

        code = 'Timeout'
        message = 'Request timeout.'
        # upload part
        stub_request(:put, /#{object_url}\?partNumber.*/)
          .to_return(:status => 200).times(3).then
          .to_return(:status => 500, :body => mock_error(code, message)).times(2).then
          .to_return(:status => 200).times(6).then
          .to_return(:status => 500, :body => mock_error(code, message)).then
          .to_return(:status => 200)

        success = false
        4.times do
          begin
            @bucket.resumable_upload(
              @object_key, @file, part_size: 10, threads: 1)
            success = true
          rescue
            # pass
          end
        end

        expect(success).to be true

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(1)

        part_numbers = Set.new([])
        upload_ids = Set.new([])

        expect(WebMock).to have_requested(
          :put, /#{object_url}\?partNumber.*/).with{ |req|
          query = parse_query_from_uri(req.uri)
          part_numbers << query['partNumber']
          upload_ids << query['uploadId']
        }.times(13)

        expect(part_numbers.to_a).to match_array((1..10).map{ |x| x.to_s })
        expect(upload_ids.to_a).to match_array(['upload_id'])

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploadId.*/).times(1)
      end

      it "should resume when checkpoint fails" do
        # Monkey patch to inject failures
        class ::Aliyun::OSS::Multipart::Upload
          alias :old_checkpoint :checkpoint

          def checkpoint_fails
            @@fail_injections ||= [false, false, true, true, false, true, false]
            @@fail_injections.shift
          end

          def checkpoint
            t = checkpoint_fails
            if t == true
              raise ClientError.new("fail injection")
            end

            old_checkpoint
          end
        end

        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))
        stub_request(:put, /#{object_url}\?partNumber.*/)
        stub_request(:post, /#{object_url}\?uploadId.*/)

        success = false
        4.times do
          begin
            @bucket.resumable_upload(
              @object_key, @file, part_size: 10, threads: 1)
            success = true
          rescue
            # pass
          end
        end

        expect(success).to be true

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(1)

        part_numbers = Set.new([])

        expect(WebMock).to have_requested(
          :put, /#{object_url}\?partNumber.*/).with{ |req|
          query = parse_query_from_uri(req.uri)
          part_numbers << query['partNumber']
          query['uploadId'] == 'upload_id'
        }.times(13)

        expect(part_numbers.to_a).to match_array((1..10).map{ |x| x.to_s })

        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploadId.*/).times(1)
      end

      it "should resume when commit txn fails" do
        # begin multipart
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))

        # upload part
        stub_request(:put, /#{object_url}\?partNumber.*/)

        code = 'Timeout'
        message = 'Request timeout.'
        # commit multipart
        stub_request(:post, /#{object_url}\?uploadId.*/)
          .to_return(:status => 500, :body => mock_error(code, message)).times(2).then
          .to_return(:status => 200)

        success = false
        3.times do
          begin
            @bucket.resumable_upload(
              @object_key, @file, part_size: 10, threads: 1)
            success = true
          rescue
            # pass
          end
        end

        expect(success).to be true
        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(1)
        expect(WebMock).to have_requested(
          :put, /#{object_url}\?partNumber.*/).times(10)
        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploadId.*/).with{ |req|
          query = parse_query_from_uri(req.uri)
          query['uploadId'] == 'upload_id'
        }.times(3)
      end

      it "should not write checkpoint when specify disable_cpt" do
        # begin multipart
        stub_request(:post, /#{object_url}\?uploads.*/)
          .to_return(:body => mock_txn_id('upload_id'))

        # upload part
        stub_request(:put, /#{object_url}\?partNumber.*/)

        code = 'Timeout'
        message = 'Request timeout.'
        # commit multipart
        stub_request(:post, /#{object_url}\?uploadId.*/)
          .to_return(:status => 500, :body => mock_error(code, message)).times(2).then
          .to_return(:status => 200)

        cpt_file = "#{File.expand_path(@file)}.cpt"
        success = false
        3.times do
          begin
            @bucket.resumable_upload(
              @object_key, @file, :part_size => 10,
              :cpt_file => cpt_file, :disable_cpt => true)
            success = true
          rescue
            # pass
          end

          expect(File.exists?(cpt_file)).to be false
        end

        expect(success).to be true
        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploads.*/).times(3)
        expect(WebMock).to have_requested(
          :put, /#{object_url}\?partNumber.*/).times(30)
        expect(WebMock).to have_requested(
          :post, /#{object_url}\?uploadId.*/).with{ |req|
          query = parse_query_from_uri(req.uri)
          query['uploadId'] == 'upload_id'
        }.times(3)
      end

    end # Resumable upload

  end # OSS
end # Aliyun
