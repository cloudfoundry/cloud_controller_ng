# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Object" do

      before :all do
        @endpoint = 'oss.aliyuncs.com'
        @protocol = Protocol.new(
          Config.new(:endpoint => @endpoint,
                     :access_key_id => 'xxx', :access_key_secret => 'yyy'))
        @bucket = 'rubysdk-bucket'
      end

      def crc_protocol
        Protocol.new(
          Config.new(:endpoint => @endpoint,
                     :access_key_id => 'xxx',
                     :access_key_secret => 'yyy',
                     :upload_crc_enable => true,
                     :download_crc_enable => true))
      end

      def get_request_path(object = nil)
        p = "#{@bucket}.#{@endpoint}/"
        p += CGI.escape(object) if object
        p
      end

      def get_resource_path(object, bucket = nil)
        "/#{bucket || @bucket}/#{object}"
      end

      def mock_copy_object(last_modified, etag)
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.CopyObjectResult {
            xml.LastModified last_modified.to_s
            xml.ETag etag
          }
        end

        builder.to_xml
      end

      def mock_acl(acl)
        Nokogiri::XML::Builder.new do |xml|
          xml.AccessControlPolicy {
            xml.Owner {
              xml.ID 'owner_id'
              xml.DisplayName 'owner_name'
            }

            xml.AccessControlList {
              xml.Grant acl
            }
          }
        end.to_xml
      end

      def mock_delete(objects, opts = {})
        # It may have invisible chars in object key which will corrupt
        # libxml. So we're constructing xml body manually here.
        body = '<?xml version="1.0"?>'
        body << '<Delete>'
        body << '<Quiet>' << (opts[:quiet]? true : false).to_s << '</Quiet>'
        objects.each { |k|
          body << '<Object><Key>' << k << '</Key></Object>'
        }
        body << '</Delete>'
      end

      def mock_delete_result(deleted, opts = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.DeleteResult {
            xml.EncodingType opts[:encoding] if opts[:encoding]
            deleted.each do |o|
              xml.Deleted {
                xml.Key o
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

      context "Put object" do

        it "should PUT to create object" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          content = "hello world"
          @protocol.put_object(@bucket, object_name) do |c|
            c << content
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          code = 'NoSuchBucket'
          message = 'The bucket does not exist.'
          stub_request(:put, url).to_return(
            :status => 404, :body => mock_error(code, message))

          content = "hello world"
          expect {
            @protocol.put_object(@bucket, object_name) do |c|
              c << content
            end
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end

        it "should use default content-type" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          @protocol.put_object(@bucket, object_name) do |content|
            content << 'hello world'
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => 'hello world',
                  :headers => {'Content-Type' => HTTP::DEFAULT_CONTENT_TYPE})
        end

        it "should use customized content-type" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          @protocol.put_object(
            @bucket, object_name, :content_type => 'application/ruby'
          ) do |content|
            content << 'hello world'
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => 'hello world',
                  :headers => {'Content-Type' => 'application/ruby'})
        end

        it "should support non-ascii object name" do
          object_name = '中国のruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          content = "hello world"
          @protocol.put_object(@bucket, object_name) do |c|
            c << content
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => content, :query => {})
        end

        it "should set user defined metas" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:put, url)

          @protocol.put_object(
            @bucket, object_name, :metas => {'year' => '2015', 'people' => 'mary'}
          ) do |content|
            content << 'hello world'
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => 'hello world',
                  :headers => {
                    'x-oss-meta-year' => '2015',
                    'x-oss-meta-people' => 'mary'})
        end

        it "should raise crc exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)
          stub_request(:put, url).to_return(
            :status => 200, :headers => {:x_oss_hash_crc64ecma => content_crc.to_i + 1})
          expect(crc_protocol.upload_crc_enable).to eq(true)
          expect {
            crc_protocol.put_object(@bucket, object_name) do |c|
              c << content
            end
          }.to raise_error(CrcInconsistentError, "The crc of put between client and oss is not inconsistent.")
        end

        it "should not raise crc exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)
          stub_request(:put, url).to_return(
            :status => 200, :headers => {:x_oss_hash_crc64ecma => content_crc})
          expect(crc_protocol.upload_crc_enable).to eq(true)
          expect {
            crc_protocol.put_object(@bucket, object_name) do |c|
              c << content
            end
          }.not_to raise_error
        end
      end # put object

      context "Append object" do

        it "should POST to append object" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'append' => nil, 'position' => 11}
          return_headers = {'x-oss-next-append-position' => '101'}
          stub_request(:post, url).with(:query => query)
            .to_return(:headers => return_headers)

          content = "hello world"
          next_pos = @protocol.append_object(@bucket, object_name, 11) do |c|
            c << content
          end

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
          expect(next_pos).to eq(101)
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'append' => nil, 'position' => 11}
          code = 'ObjectNotAppendable'
          message = 'Normal object cannot be appended.'
          stub_request(:post, url).with(:query => query).
            to_return(:status => 409, :body => mock_error(code, message))

          content = "hello world"
          expect {
            @protocol.append_object(@bucket, object_name, 11) do |c|
              c << content
            end
          }.to raise_error(Exception, err(message))

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
        end

        it "should use default content-type" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          query = {'append' => nil, 'position' => 0}

          stub_request(:post, url).with(:query => query)

          @protocol.append_object(@bucket, object_name, 0) do |content|
            content << 'hello world'
          end

          expect(WebMock).to have_requested(:post, url)
            .with(:body => 'hello world',
                  :query => query,
                  :headers => {'Content-Type' => HTTP::DEFAULT_CONTENT_TYPE})
        end

        it "should use customized content-type" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          query = {'append' => nil, 'position' => 0}

          stub_request(:post, url).with(:query => query)

          @protocol.append_object(
            @bucket, object_name, 0, :content_type => 'application/ruby'
          ) do |content|
            content << 'hello world'
          end

          expect(WebMock).to have_requested(:post, url)
            .with(:body => 'hello world',
                  :query => query,
                  :headers => {'Content-Type' => 'application/ruby'})
        end

        it "should set user defined metas" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          query = {'append' => nil, 'position' => 0}

          stub_request(:post, url).with(:query => query)

          @protocol.append_object(
            @bucket, object_name, 0, :metas => {'year' => '2015', 'people' => 'mary'}
          ) do |content|
            content << 'hello world'
          end

          expect(WebMock).to have_requested(:post, url)
                         .with(:query => query,
                               :body => 'hello world',
                               :headers => {
                                 'x-oss-meta-year' => '2015',
                                 'x-oss-meta-people' => 'mary'})
        end

        it "should raise crc exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)

          query = {'append' => nil, 'position' => 11}
          return_headers = {'x-oss-next-append-position' => '101', :x_oss_hash_crc64ecma => content_crc.to_i + 1}
          stub_request(:post, url).with(:query => query)
            .to_return(:headers => return_headers)
          expect(crc_protocol.upload_crc_enable).to eq(true)
          expect {
            crc_protocol.append_object(@bucket, object_name, 11, :init_crc => 0) do |c|
              c << content
            end
          }.to raise_error(CrcInconsistentError, "The crc of append between client and oss is not inconsistent.")
        end

        it "should not raise crc exception with init_crc" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)

          query = {'append' => nil, 'position' => 11}
          return_headers = {'x-oss-next-append-position' => '101', :x_oss_hash_crc64ecma => content_crc}
          stub_request(:post, url).with(:query => query)
            .to_return(:headers => return_headers)

          expect(crc_protocol.upload_crc_enable).to eq(true)
          next_pos = 0
          expect {
            next_pos = crc_protocol.append_object(@bucket, object_name, 11, :init_crc => 0) do |c|
              c << content
            end
          }.not_to raise_error

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
          expect(next_pos).to eq(101)
        end

        it "should not raise crc exception without init_crc" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)

          query = {'append' => nil, 'position' => 11}
          return_headers = {'x-oss-next-append-position' => '101', :x_oss_hash_crc64ecma => content_crc + 1}
          stub_request(:post, url).with(:query => query)
            .to_return(:headers => return_headers)

          expect(crc_protocol.upload_crc_enable).to eq(true)
          next_pos = 0
          expect {
            next_pos = crc_protocol.append_object(@bucket, object_name, 11) do |c|
              c << content
            end
          }.not_to raise_error

          expect(WebMock).to have_requested(:post, url)
            .with(:body => content, :query => query)
          expect(next_pos).to eq(101)
        end
      end # append object

      context "Copy object" do

        it "should copy object" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          last_modified = Time.parse(Time.now.rfc822)
          etag = '0000'
          stub_request(:put, url).to_return(
            :body => mock_copy_object(last_modified, etag))

          result = @protocol.copy_object(@bucket, src_object, dst_object)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => {
                    'x-oss-copy-source' => get_resource_path(src_object)})

          expect(result[:last_modified]).to eq(last_modified)
          expect(result[:etag]).to eq(etag)
        end

        it "should copy object of different buckets" do
          src_bucket = 'source-bucket'
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          last_modified = Time.parse(Time.now.rfc822)
          etag = '0000'
          stub_request(:put, url).to_return(
            :body => mock_copy_object(last_modified, etag))

          result = @protocol.copy_object(
            @bucket, src_object, dst_object, :src_bucket => src_bucket)

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => {
                    'x-oss-copy-source' => get_resource_path(src_object, src_bucket)})

          expect(result[:last_modified]).to eq(last_modified)
          expect(result[:etag]).to eq(etag)
        end

        it "should set acl and conditions when copy object" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          modified_since = Time.now
          unmodified_since = Time.now
          last_modified = Time.parse(Time.now.rfc822)
          etag = '0000'

          headers = {
            'x-oss-copy-source' => get_resource_path(src_object),
            'x-oss-object-acl' => ACL::PRIVATE,
            'x-oss-metadata-directive' => MetaDirective::REPLACE,
            'x-oss-copy-source-if-modified-since' => modified_since.httpdate,
            'x-oss-copy-source-if-unmodified-since' => unmodified_since.httpdate,
            'x-oss-copy-source-if-match' => 'me',
            'x-oss-copy-source-if-none-match' => 'ume'
          }
          stub_request(:put, url).to_return(
            :body => mock_copy_object(last_modified, etag))

          result = @protocol.copy_object(
            @bucket, src_object, dst_object,
            {:acl => ACL::PRIVATE,
             :meta_directive => MetaDirective::REPLACE,
             :condition => {
               :if_modified_since => modified_since,
               :if_unmodified_since => unmodified_since,
               :if_match_etag => 'me',
               :if_unmatch_etag => 'ume'
             }
            })

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => headers)

          expect(result[:last_modified]).to eq(last_modified)
          expect(result[:etag]).to eq(etag)
        end

        it "should set user defined metas" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          stub_request(:put, url)

          @protocol.copy_object(@bucket, src_object, dst_object,
                               :metas => {
                                 'year' => '2015',
                                 'people' => 'mary'
                               })

          expect(WebMock).to have_requested(:put, url)
                         .with(:body => nil,
                               :headers => {
                                 'x-oss-meta-year' => '2015',
                                 'x-oss-meta-people' => 'mary'})
        end

        it "should raise Exception on error" do
          src_object = 'ruby'
          dst_object = 'rails'
          url = get_request_path(dst_object)

          code = 'EntityTooLarge'
          message = 'The object to copy is too large.'
          stub_request(:put, url).to_return(
            :status => 400,
            :headers => {'x-oss-request-id' => '0000'},
            :body => mock_error(code, message))

          begin
            @protocol.copy_object(@bucket, src_object, dst_object)
            expect(false).to be true
          rescue ServerError => e
            expect(e.http_code).to eq(400)
            expect(e.error_code).to eq(code)
            expect(e.message).to eq(err(message))
            expect(e.request_id).to eq('0000')
          end

          expect(WebMock).to have_requested(:put, url)
            .with(:body => nil, :headers => {
                  'x-oss-copy-source' => get_resource_path(src_object)})
        end
      end # copy object

      context "Get object" do

        it "should GET to get object" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          return_content = "hello world"
          stub_request(:get, url).to_return(:body => return_content)

          content = ""
          @protocol.get_object(@bucket, object_name) {|c| content << c}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})

          expect(content).to eq(return_content)
        end

        it "should return object meta" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          last_modified = Time.now.rfc822
          return_headers = {
            'x-oss-object-type' => 'Normal',
            'ETag' => 'xxxyyyzzz',
            'Content-Length' => 1024,
            'Last-Modified' => last_modified,
            'x-oss-meta-year' => '2015',
            'x-oss-meta-people' => 'mary'
          }
          return_content = "hello world"
          stub_request(:get, url)
            .to_return(:headers => return_headers, :body => return_content)

          content = ""
          obj = @protocol.get_object(@bucket, object_name) {|c| content << c}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})

          expect(content).to eq(return_content)
          expect(obj.key).to eq(object_name)
          expect(obj.type).to eq('Normal')
          expect(obj.etag).to eq('xxxyyyzzz')
          expect(obj.size).to eq(1024)
          expect(obj.last_modified.rfc822).to eq(last_modified)
          expect(obj.metas).to eq({'year' => '2015', 'people' => 'mary'})
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          code = 'NoSuchKey'
          message = 'The object does not exist'
          stub_request(:get, url).to_return(
            :status => 404, :body => mock_error(code, message))

          expect {
            @protocol.get_object(@bucket, object_name) {|c| true}
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})
        end

        it "should get object range" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:get, url)

          @protocol.get_object(@bucket, object_name, {:range => [0, 10]}) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'Range' => 'bytes=0-9'
                  })
        end

        it "should raise Exception on error when setting invalid range" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          stub_request(:get, url)
          expect {
            @protocol.get_object(@bucket, object_name, {:range => [0, 10, 5]}) {}
          }.to raise_error(ClientError)
        end

        it "should match modify time and etag" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:get, url)

          modified_since = Time.now
          unmodified_since = Time.now
          etag = 'xxxyyyzzz'
          not_etag = 'aaabbbccc'
          @protocol.get_object(
            @bucket, object_name,
            {:condition => {
               :if_modified_since => modified_since,
               :if_unmodified_since => unmodified_since,
               :if_match_etag => etag,
               :if_unmatch_etag => not_etag}}) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'If-Modified-Since' => modified_since.httpdate,
                    'If-Unmodified-since' => unmodified_since.httpdate,
                    'If-Match' => etag,
                    'If-None-Match' => not_etag})
        end

        it "should rewrite response headers" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          expires = Time.now
          rewrites = {
               :content_type => 'ct',
               :content_language => 'cl',
               :expires => expires,
               :cache_control => 'cc',
               :content_disposition => 'cd',
               :content_encoding => 'ce'
          }
          query = Hash[rewrites.map {|k, v| ["response-#{k.to_s.sub('_', '-')}", v]}]
          query['response-expires'] = rewrites[:expires].httpdate

          stub_request(:get, url).with(:query => query)

          @protocol.get_object(@bucket, object_name, :rewrite => rewrites) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => query)
        end

        it "should get object with headers" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          headers = {
            'Range' => 'bytes=0-9'
          }
          stub_request(:get, url)

          @protocol.get_object(@bucket, object_name, {:headers => headers}) {}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'Range' => 'bytes=0-9'
                  })
        end

        it "should raise crc exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)
          stub_request(:get, url).to_return(
            :status => 200, :body => content, :headers => {:x_oss_hash_crc64ecma => content_crc.to_i + 1})
          response_content = ""
          expect(crc_protocol.download_crc_enable).to eq(true)
          expect {
            crc_protocol.get_object(@bucket, object_name) {|c| response_content << c}
          }.to raise_error(CrcInconsistentError, "The crc of get between client and oss is not inconsistent.")
        end

        it "should not raise crc exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world"
          content_crc = Aliyun::OSS::Util.crc(content)
          stub_request(:get, url).to_return(
            :status => 200, :body => content, :headers => {:x_oss_hash_crc64ecma => content_crc})
          response_content = ""
          expect(crc_protocol.download_crc_enable).to eq(true)
          expect {
            crc_protocol.get_object(@bucket, object_name) {|c| response_content << c}
          }.not_to raise_error
          expect(response_content).to eq(content)
        end

        it "should not raise crc exception on error when setting range" do
          object_name = 'ruby'
          url = get_request_path(object_name)
          content = "hello world 0123456789"
          content_crc = Aliyun::OSS::Util.crc(content)
          stub_request(:get, url).to_return(
            :status => 200, :body => content, :headers => {:x_oss_hash_crc64ecma => content_crc.to_i + 1})
          response_content = ""
          expect(crc_protocol.download_crc_enable).to eq(true)
          expect {
            crc_protocol.get_object(@bucket, object_name, {range: [0, 10]}) {|c| response_content << c}
          }.not_to raise_error
          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'Range' => 'bytes=0-9'
                  })
        end

        it "should get to get object with special chars" do
          object_name = 'ruby///adfadfa//!@#%^*//?key=value&aabc#abc=ad'
          url = get_request_path(object_name)

          return_content = "hello world"
          stub_request(:get, url).to_return(:body => return_content)

          content = ""
          @protocol.get_object(@bucket, object_name) {|c| content << c}

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => {})

          expect(content).to eq(return_content)
        end

      end # Get object

      context "Get object meta" do

        it "should get object meta" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          last_modified = Time.now.rfc822
          return_headers = {
            'x-oss-object-type' => 'Normal',
            'ETag' => 'xxxyyyzzz',
            'Content-Length' => 1024,
            'Last-Modified' => last_modified,
            'x-oss-meta-year' => '2015',
            'x-oss-meta-people' => 'mary'
          }
          stub_request(:head, url).to_return(:headers => return_headers)

          obj = @protocol.get_object_meta(@bucket, object_name)

          expect(WebMock).to have_requested(:head, url)
            .with(:body => nil, :query => {})

          expect(obj.key).to eq(object_name)
          expect(obj.type).to eq('Normal')
          expect(obj.etag).to eq('xxxyyyzzz')
          expect(obj.size).to eq(1024)
          expect(obj.last_modified.rfc822).to eq(last_modified)
          expect(obj.metas).to eq({'year' => '2015', 'people' => 'mary'})
        end

        it "should set conditions" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:head, url)

          modified_since = Time.now
          unmodified_since = Time.now
          etag = 'xxxyyyzzz'
          not_etag = 'aaabbbccc'

          @protocol.get_object_meta(
            @bucket, object_name,
            :condition => {
              :if_modified_since => modified_since,
              :if_unmodified_since => unmodified_since,
              :if_match_etag => etag,
              :if_unmatch_etag => not_etag})

          expect(WebMock).to have_requested(:head, url)
            .with(:body => nil, :query => {},
                  :headers => {
                    'If-Modified-Since' => modified_since.httpdate,
                    'If-Unmodified-since' => unmodified_since.httpdate,
                    'If-Match' => etag,
                    'If-None-Match' => not_etag})
        end
      end # Get object meta

      context "Delete object" do

        it "should DELETE to delete object" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          stub_request(:delete, url)

          @protocol.delete_object(@bucket, object_name)

          expect(WebMock).to have_requested(:delete, url)
            .with(:body => nil, :query => {})
        end

        it "should raise Exception on error" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          code = 'NoSuchBucket'
          message = 'The bucket does not exist.'
          stub_request(:delete, url).to_return(
            :status => 404, :body => mock_error(code, message))

          expect {
            @protocol.delete_object(@bucket, object_name)
          }.to raise_error(ServerError, err(message))

          expect(WebMock).to have_requested(:delete, url)
            .with(:body => nil, :query => {})
        end

        it "should batch delete objects" do
          url = get_request_path
          query = {'delete' => nil}

          object_names = (1..5).map do |i|
            "object-#{i}"
          end

          stub_request(:post, url)
            .with(:query => query)
            .to_return(:body => mock_delete_result(object_names))

          opts = {:quiet => false}
          deleted = @protocol.batch_delete_objects(@bucket, object_names, opts)

          expect(WebMock).to have_requested(:post, url)
            .with(:query => query, :body => mock_delete(object_names, opts))
          expect(deleted).to match_array(object_names)
        end

        it "should decode object key in batch delete response" do
          url = get_request_path
          query = {'delete' => nil, 'encoding-type' => KeyEncoding::URL}

          object_names = (1..5).map do |i|
            "对象-#{i}"
          end
          es_objects = (1..5).map do |i|
            CGI.escape "对象-#{i}"
          end
          opts = {:quiet => false, :encoding => KeyEncoding::URL}

          stub_request(:post, url)
            .with(:query => query)
            .to_return(:body => mock_delete_result(es_objects, opts))

          deleted = @protocol.batch_delete_objects(@bucket, object_names, opts)

          expect(WebMock).to have_requested(:post, url)
            .with(:query => query, :body => mock_delete(object_names, opts))
          expect(deleted).to match_array(object_names)
        end

        it "should batch delete objects in quiet mode" do
          url = get_request_path
          query = {'delete' => nil}

          object_names = (1..5).map do |i|
            "object-#{i}"
          end

          stub_request(:post, url)
            .with(:query => query)
            .to_return(:body => "")

          opts = {:quiet => true}
          deleted = @protocol.batch_delete_objects(@bucket, object_names, opts)

          expect(WebMock).to have_requested(:post, url)
            .with(:query => query, :body => mock_delete(object_names, opts))
          expect(deleted).to match_array([])
        end

        it "should rasie Exception wiht invalid responsed body" do
          url = get_request_path
          query = {'delete' => nil}
          body = '<DeleteResult>
                    <EncodingType>invaid<EncodingType>
                    <Deleted>
                      <Key>multipart.data</Key>
                    </Deleted>
                    <Deleted>
                      <Key>test.jpg</Key>
                    </Deleted>
                    <Deleted>
                      <Key>demo.jpg</Key>
                    </Deleted>
                  </DeleteResult>'

          object_names = (1..5).map do |i|
            "object-#{i}"
          end

          stub_request(:post, url)
            .with(:query => query)
            .to_return(:body => body)

          opts = {:quiet => false}
          expect {
            deleted = @protocol.batch_delete_objects(@bucket, object_names, opts)
          }.to raise_error(ClientError)

        end
      end # delete object

      context "acl" do
        it "should update acl" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'acl' => nil}
          stub_request(:put, url).with(:query => query)

          @protocol.put_object_acl(@bucket, object_name, ACL::PUBLIC_READ)

          expect(WebMock).to have_requested(:put, url)
            .with(:query => query,
                  :headers => {'x-oss-object-acl' => ACL::PUBLIC_READ},
                  :body => nil)
        end

        it "should get acl" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          query = {'acl' => nil}
          return_acl = ACL::PUBLIC_READ

          stub_request(:get, url)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl))

          acl = @protocol.get_object_acl(@bucket, object_name)

          expect(WebMock).to have_requested(:get, url)
            .with(:body => nil, :query => query)
          expect(acl).to eq(return_acl)
        end
      end # acl

      context "cors" do
        it "should get object cors" do
          object_name = 'ruby'
          url = get_request_path(object_name)

          return_rule = CORSRule.new(
            :allowed_origins => 'origin',
            :allowed_methods => 'PUT',
            :allowed_headers => 'Authorization',
            :expose_headers => 'x-oss-test',
            :max_age_seconds => 10
          )
          stub_request(:options, url).to_return(
            :headers => {
              'Access-Control-Allow-Origin' => return_rule.allowed_origins,
              'Access-Control-Allow-Methods' => return_rule.allowed_methods,
              'Access-Control-Allow-Headers' => return_rule.allowed_headers,
              'Access-Control-Expose-Headers' => return_rule.expose_headers,
              'Access-Control-Max-Age' => return_rule.max_age_seconds
            }
          )

          rule = @protocol.get_object_cors(
            @bucket, object_name, 'origin', 'PUT', ['Authorization'])

          expect(WebMock).to have_requested(:options, url)
            .with(:body => nil, :query => {})
          expect(rule.to_s).to eq(return_rule.to_s)
        end
      end # cors

      context "callback" do
        it "should encode callback" do
          callback = Callback.new(
            url: 'http://app.server.com/callback',
            query: {'id' => 1, 'name' => '杭州'},
            body: 'hello world',
            host: 'server.com'
          )

          encoded = "eyJjYWxsYmFja1VybCI6Imh0dHA6Ly9hcHAuc2VydmVyLmNvbS9jYWxsYmFjaz9pZD0xJm5hbWU9JUU2JTlEJUFEJUU1JUI3JTlFIiwiY2FsbGJhY2tCb2R5IjoiaGVsbG8gd29ybGQiLCJjYWxsYmFja0JvZHlUeXBlIjoiYXBwbGljYXRpb24veC13d3ctZm9ybS11cmxlbmNvZGVkIiwiY2FsbGJhY2tIb3N0Ijoic2VydmVyLmNvbSJ9"
          expect(callback.serialize).to eq(encoded)
        end

        it "should not accept url with query string" do
          expect {
            Callback.new(url: 'http://app.server.com/callback?id=1').serialize
          }.to raise_error(ClientError, "Query parameters should not appear in URL.")
        end

      end
    end # Object

  end # OSS
end # Aliyun
