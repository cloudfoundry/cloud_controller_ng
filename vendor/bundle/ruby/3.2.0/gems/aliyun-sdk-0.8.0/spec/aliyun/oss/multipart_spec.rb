# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe Multipart do

      before :all do
        @endpoint = 'oss.aliyuncs.com'
        @protocol = Protocol.new(
          Config.new(:endpoint => @endpoint,
                     :access_key_id => 'xxx', :access_key_secret => 'yyy'))

        @bucket = 'rubysdk-bucket'
        @object = 'rubysdk-object'
      end

      def request_path
        "#{@bucket}.#{@endpoint}/#{@object}"
      end

      def crc_protocol
        Protocol.new(
          Config.new(:endpoint => @endpoint,
                     :access_key_id => 'xxx',
                     :access_key_secret => 'yyy',
                     :upload_crc_enable => true,
                     :download_crc_enable => true))
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

      def mock_multiparts(multiparts, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListMultipartUploadsResult {
            {
              :prefix => 'Prefix',
              :limit => 'MaxUploads',
              :id_marker => 'UploadIdMarker',
              :next_id_marker => 'NextUploadIdMarker',
              :key_marker => 'KeyMarker',
              :next_key_marker => 'NextKeyMarker',
              :truncated => 'IsTruncated',
              :encoding => 'EncodingType'
            }.map do |k, v|
              xml.send(v, more[k]) if more[k]
            end

            multiparts.each do |m|
              xml.Upload {
                xml.Key m.object
                xml.UploadId m.id
                xml.Initiated m.creation_time.rfc822
              }
            end
          }
        end.to_xml
      end

      def mock_parts(parts, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListPartsResult {
            {
              :marker => 'PartNumberMarker',
              :next_marker => 'NextPartNumberMarker',
              :limit => 'MaxParts',
              :truncated => 'IsTruncated',
              :encoding => 'EncodingType'
            }.map do |k, v|
              xml.send(v, more[k]) if more[k]
            end

            parts.each do |p|
              xml.Part {
                xml.PartNumber p.number
                xml.LastModified p.last_modified.rfc822
                xml.ETag p.etag
                xml.Size p.size
              }
            end
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

      context "Initiate multipart upload" do

        it "should POST to create transaction" do
          query = {'uploads' => nil}
          stub_request(:post, request_path).with(:query => query)

          @protocol.initiate_multipart_upload(
            @bucket, @object, :metas => {
              'year' => '2015',
              'people' => 'mary'
            })

          expect(WebMock).to have_requested(:post, request_path)
                         .with(:body => nil, :query => query,
                               :headers => {
                                 'x-oss-meta-year' => '2015',
                                 'x-oss-meta-people' => 'mary'
                               })
        end

        it "should return transaction id" do
          query = {'uploads' => nil}
          return_txn_id = 'zyx'
          stub_request(:post, request_path).
            with(:query => query).
            to_return(:body => mock_txn_id(return_txn_id))

          txn_id = @protocol.initiate_multipart_upload(@bucket, @object)

          expect(WebMock).to have_requested(:post, request_path)
            .with(:body => nil, :query => query)
          expect(txn_id).to eq(return_txn_id)
        end

        it "should raise Exception on error" do
          query = {'uploads' => nil}

          code = 'InvalidArgument'
          message = 'Invalid argument.'
          stub_request(:post, request_path)
            .with(:query => query)
            .to_return(:status => 400, :body => mock_error(code, message))

          expect {
            @protocol.initiate_multipart_upload(@bucket, @object)
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:post, request_path)
            .with(:body => nil, :query => query)
        end
      end # initiate multipart

      context "Upload part" do

        it "should PUT to upload a part" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          query = {'partNumber' => part_no, 'uploadId' => txn_id}

          stub_request(:put, request_path).with(:query => query)

          @protocol.upload_part(@bucket, @object, txn_id, part_no) {}

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query)
        end

        it "should return part etag" do
          part_no = 1
          txn_id = 'xxxyyyzzz'
          query = {'partNumber' => part_no, 'uploadId' => txn_id}

          return_etag = 'etag_1'
          stub_request(:put, request_path)
            .with(:query => query)
            .to_return(:headers => {'ETag' => return_etag})

          body = 'hello world'
          p = @protocol.upload_part(@bucket, @object, txn_id, part_no) do |content|
            content << body
          end

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => body, :query => query)
          expect(p.number).to eq(part_no)
          expect(p.etag).to eq(return_etag)
        end

        it "should raise Exception on error" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          query = {'partNumber' => part_no, 'uploadId' => txn_id}

          code = 'InvalidArgument'
          message = 'Invalid argument.'

          stub_request(:put, request_path)
            .with(:query => query)
            .to_return(:status => 400, :body => mock_error(code, message))

          expect {
            @protocol.upload_part(@bucket, @object, txn_id, part_no) {}
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query)
        end

        it "should raise crc exception on error" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          query = {'partNumber' => part_no, 'uploadId' => txn_id}

          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)

          stub_request(:put, request_path).with(:query => query).to_return(
            :status => 200, :headers => {:x_oss_hash_crc64ecma => content_crc + 1})

          expect {
            crc_protocol.upload_part(@bucket, @object, txn_id, part_no) do |body|
              body << content
            end
          }.to raise_error(CrcInconsistentError, "The crc of put between client and oss is not inconsistent.")
        end

        it "should not raise crc exception on error" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          query = {'partNumber' => part_no, 'uploadId' => txn_id}

          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)

          stub_request(:put, request_path).with(:query => query).to_return(
            :status => 200, :headers => {:x_oss_hash_crc64ecma => content_crc})

          expect {
            crc_protocol.upload_part(@bucket, @object, txn_id, part_no) do |body|
              body << content
            end
          }.not_to raise_error
        end

      end # upload part

      context "Upload part by copy object" do

        it "should PUT to upload a part by copy object" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          copy_source = "/#{@bucket}/src_obj"

          query = {'partNumber' => part_no, 'uploadId' => txn_id}
          headers = {'x-oss-copy-source' => copy_source}

          stub_request(:put, request_path)
            .with(:query => query, :headers => headers)

          @protocol.upload_part_by_copy(@bucket, @object, txn_id, part_no, 'src_obj')

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query, :headers => headers)
        end

        it "should upload a part by copy object from different bucket" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          src_bucket = 'source-bucket'
          copy_source = "/#{src_bucket}/src_obj"

          query = {'partNumber' => part_no, 'uploadId' => txn_id}
          headers = {'x-oss-copy-source' => copy_source}

          stub_request(:put, request_path)
            .with(:query => query, :headers => headers)

          @protocol.upload_part_by_copy(
            @bucket, @object, txn_id, part_no, 'src_obj', :src_bucket => src_bucket)

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query, :headers => headers)
        end

        it "should return part etag" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          copy_source = "/#{@bucket}/src_obj"

          query = {'partNumber' => part_no, 'uploadId' => txn_id}
          headers = {'x-oss-copy-source' => copy_source}
          return_etag = 'etag_1'

          stub_request(:put, request_path)
            .with(:query => query, :headers => headers)
            .to_return(:headers => {'ETag' => return_etag})

          p = @protocol.upload_part_by_copy(@bucket, @object, txn_id, part_no, 'src_obj')

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query, :headers => headers)
          expect(p.number).to eq(part_no)
          expect(p.etag).to eq(return_etag)
        end

        it "should set range and conditions when copy" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          copy_source = "/#{@bucket}/src_obj"

          query = {'partNumber' => part_no, 'uploadId' => txn_id}
          modified_since = Time.now
          unmodified_since = Time.now
          headers = {
            'Range' => 'bytes=1-4',
            'x-oss-copy-source' => copy_source,
            'x-oss-copy-source-if-modified-since' => modified_since.httpdate,
            'x-oss-copy-source-if-unmodified-since' => unmodified_since.httpdate,
            'x-oss-copy-source-if-match' => 'me',
            'x-oss-copy-source-if-none-match' => 'ume'
          }
          return_etag = 'etag_1'

          stub_request(:put, request_path)
            .with(:query => query, :headers => headers)
            .to_return(:headers => {'ETag' => return_etag})

          p = @protocol.upload_part_by_copy(
            @bucket, @object, txn_id, part_no, 'src_obj',
            {:range => [1, 5],
             :condition => {
               :if_modified_since => modified_since,
               :if_unmodified_since => unmodified_since,
               :if_match_etag => 'me',
               :if_unmatch_etag => 'ume'
             }})

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query, :headers => headers)
          expect(p.number).to eq(part_no)
          expect(p.etag).to eq(return_etag)
        end

        it "should raise Exception on error" do
          txn_id = 'xxxyyyzzz'
          part_no = 1
          copy_source = "/#{@bucket}/src_obj"

          query = {'partNumber' => part_no, 'uploadId' => txn_id}
          headers = {'x-oss-copy-source' => copy_source}

          code = 'PreconditionFailed'
          message = 'Precondition check failed.'
          stub_request(:put, request_path)
            .with(:query => query, :headers => headers)
            .to_return(:status => 412, :body => mock_error(code, message))

          expect {
            @protocol.upload_part_by_copy(@bucket, @object, txn_id, part_no, 'src_obj')
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:put, request_path)
            .with(:body => nil, :query => query, :headers => headers)
        end
      end # upload part by copy object

      context "Commit multipart" do

        it "should POST to complete multipart" do
          txn_id = 'xxxyyyzzz'

          query = {'uploadId' => txn_id}
          parts = (1..5).map do |i|
            Multipart::Part.new(:number => i, :etag => "etag_#{i}")
          end

          stub_request(:post, request_path).with(:query => query)

          @protocol.complete_multipart_upload(@bucket, @object, txn_id, parts)

          parts_body = Nokogiri::XML::Builder.new do |xml|
            xml.CompleteMultipartUpload {
              parts.each do |p|
                xml.Part {
                  xml.PartNumber p.number
                  xml.ETag p.etag
                }
              end
            }
          end.to_xml

          expect(WebMock).to have_requested(:post, request_path)
            .with(:body => parts_body, :query => query)
        end

        it "should raise Exception on error" do
          txn_id = 'xxxyyyzzz'
          query = {'uploadId' => txn_id}

          code = 'InvalidDigest'
          message = 'Content md5 does not match.'

          stub_request(:post, request_path)
            .with(:query => query)
            .to_return(:status => 400, :body => mock_error(code, message))

          expect {
            @protocol.complete_multipart_upload(@bucket, @object, txn_id, [])
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:post, request_path)
            .with(:query => query)
        end
      end # commit multipart

      context "Abort multipart" do

        it "should DELETE to abort multipart" do
          txn_id = 'xxxyyyzzz'

          query = {'uploadId' => txn_id}

          stub_request(:delete, request_path).with(:query => query)

          @protocol.abort_multipart_upload(@bucket, @object, txn_id)

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:body => nil, :query => query)
        end

        it "should raise Exception on error" do
          txn_id = 'xxxyyyzzz'
          query = {'uploadId' => txn_id}

          code = 'NoSuchUpload'
          message = 'The multipart transaction does not exist.'

          stub_request(:delete, request_path)
            .with(:query => query)
            .to_return(:status => 404, :body => mock_error(code, message))

          expect {
            @protocol.abort_multipart_upload(@bucket, @object, txn_id)
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:delete, request_path)
            .with(:body => nil, :query => query)
        end
      end # abort multipart

      context "List multiparts" do

        it "should GET to list multiparts" do
          request_path = "#{@bucket}.#{@endpoint}/"
          query = {'uploads' => nil}

          stub_request(:get, request_path).with(:query => query)

          @protocol.list_multipart_uploads(@bucket)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
        end

        it "should send extra params when list multiparts" do
          request_path = "#{@bucket}.#{@endpoint}/"
          query = {
            'uploads' => nil,
            'prefix' => 'foo-',
            'upload-id-marker' => 'id-marker',
            'key-marker' => 'key-marker',
            'max-uploads' => 10,
            'encoding-type' => KeyEncoding::URL
          }

          stub_request(:get, request_path).with(:query => query)

          @protocol.list_multipart_uploads(
            @bucket,
            :prefix => 'foo-',
            :id_marker => 'id-marker',
            :key_marker => 'key-marker',
            :limit => 10,
            :encoding => KeyEncoding::URL
          )

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
        end

        it "should get multipart transactions" do
          request_path = "#{@bucket}.#{@endpoint}/"
          query = {
            'uploads' => nil,
            'prefix' => 'foo-',
            'upload-id-marker' => 'id-marker',
            'key-marker' => 'key-marker',
            'max-uploads' => 100,
            'encoding-type' => KeyEncoding::URL
          }

          return_multiparts = (1..5).map do |i|
            Multipart::Transaction.new(
              :id => "id-#{i}",
              :object => "key-#{i}",
              :bucket => @bucket,
              :creation_time => Time.parse(Time.now.rfc822))
          end

          return_more = {
            :prefix => 'foo-',
            :id_marker => 'id-marker',
            :key_marker => 'key-marker',
            :next_id_marker => 'next-id-marker',
            :next_key_marker => 'next-key-marker',
            :limit => 100,
            :truncated => true
          }
          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_multiparts(return_multiparts, return_more))

          txns, more = @protocol.list_multipart_uploads(
                  @bucket,
                  :prefix => 'foo-',
                  :id_marker => 'id-marker',
                  :key_marker => 'key-marker',
                  :limit => 100,
                  :encoding => KeyEncoding::URL)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
          expect(txns.map {|x| x.to_s}.join(';'))
            .to eq(return_multiparts.map {|x| x.to_s}.join(';'))
          expect(more).to eq(return_more)
        end

        it "should decode object key" do
          request_path = "#{@bucket}.#{@endpoint}/"
          query = {
            'uploads' => nil,
            'prefix' => 'foo-',
            'upload-id-marker' => 'id-marker',
            'key-marker' => 'key-marker',
            'max-uploads' => 100,
            'encoding-type' => KeyEncoding::URL
          }

          return_multiparts = (1..5).map do |i|
            Multipart::Transaction.new(
              :id => "id-#{i}",
              :object => "中国-#{i}",
              :bucket => @bucket,
              :creation_time => Time.parse(Time.now.rfc822))
          end

          es_multiparts = return_multiparts.map do |x|
            Multipart::Transaction.new(
              :id => x.id,
              :object => CGI.escape(x.object),
              :creation_time => x.creation_time)
          end

          return_more = {
            :prefix => 'foo-',
            :id_marker => 'id-marker',
            :key_marker => '杭州のruby',
            :next_id_marker => 'next-id-marker',
            :next_key_marker => '西湖のruby',
            :limit => 100,
            :truncated => true,
            :encoding => KeyEncoding::URL
          }

          es_more = {
            :prefix => 'foo-',
            :id_marker => 'id-marker',
            :key_marker => CGI.escape('杭州のruby'),
            :next_id_marker => 'next-id-marker',
            :next_key_marker => CGI.escape('西湖のruby'),
            :limit => 100,
            :truncated => true,
            :encoding => KeyEncoding::URL
          }

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_multiparts(es_multiparts, es_more))

          txns, more = @protocol.list_multipart_uploads(
                  @bucket,
                  :prefix => 'foo-',
                  :id_marker => 'id-marker',
                  :key_marker => 'key-marker',
                  :limit => 100,
                  :encoding => KeyEncoding::URL)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
          expect(txns.map {|x| x.to_s}.join(';'))
            .to eq(return_multiparts.map {|x| x.to_s}.join(';'))
          expect(more).to eq(return_more)
        end

        it "should raise Exception on error" do
          request_path = "#{@bucket}.#{@endpoint}/"
          query = {'uploads' => nil}

          code = 'InvalidArgument'
          message = 'Invalid argument.'
          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:status => 400, :body => mock_error(code, message))

          expect {
            @protocol.list_multipart_uploads(@bucket)
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
        end
      end # list multiparts

      context "List parts" do

        it "should GET to list parts" do
          txn_id = 'yyyxxxzzz'
          query = {'uploadId' => txn_id}

          stub_request(:get, request_path).with(:query => query)

          @protocol.list_parts(@bucket, @object, txn_id)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
        end

        it "should send extra params when list parts" do
          txn_id = 'yyyxxxzzz'
          query = {
            'uploadId' => txn_id,
            'part-number-marker' => 'foo-',
            'max-parts' => 100,
            'encoding-type' => KeyEncoding::URL
          }

          stub_request(:get, request_path).with(:query => query)

          @protocol.list_parts(@bucket, @object, txn_id,
                          :marker => 'foo-',
                          :limit => 100,
                          :encoding => KeyEncoding::URL)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
        end

        it "should get parts" do
          txn_id = 'yyyxxxzzz'
          query = {
            'uploadId' => txn_id,
            'part-number-marker' => 'foo-',
            'max-parts' => 100,
            'encoding-type' => KeyEncoding::URL
          }

          return_parts = (1..5).map do |i|
            Multipart::Part.new(
              :number => i,
              :etag => "etag-#{i}",
              :size => 1024,
              :last_modified => Time.parse(Time.now.rfc822))
          end

          return_more = {
            :marker => 'foo-',
            :next_marker => 'bar-',
            :limit => 100,
            :truncated => true
          }

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:body => mock_parts(return_parts, return_more))

          parts, more = @protocol.list_parts(@bucket, @object, txn_id,
                          :marker => 'foo-',
                          :limit => 100,
                          :encoding => KeyEncoding::URL)

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
          part_numbers = return_parts.map {|x| x.number}
          expect(parts.map {|x| x.number}).to match_array(part_numbers)
          expect(more).to eq(return_more)
        end

        it "should raise Exception on error" do
          txn_id = 'yyyxxxzzz'
          query = {'uploadId' => txn_id}

          code = 'InvalidArgument'
          message = 'Invalid argument.'

          stub_request(:get, request_path)
            .with(:query => query)
            .to_return(:status => 400, :body => mock_error(code, message))

          expect {
            @protocol.list_parts(@bucket, @object, txn_id)
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:get, request_path)
            .with(:body => nil, :query => query)
        end
      end # list parts

    end # Multipart

  end # OSS
end # Aliyun
