# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe Bucket do

      before :all do
        @endpoint = 'oss-cn-hangzhou.aliyuncs.com'
        @bucket_name = 'rubysdk-bucket'
        @bucket = Client.new(
          :endpoint => @endpoint,
          :access_key_id => 'xxx',
          :access_key_secret => 'yyy').get_bucket(@bucket_name)
      end

      def bucket_url
        "#{@bucket_name}.#{@endpoint}"
      end

      def object_url(object)
        "#{@bucket_name}.#{@endpoint}/#{object}"
      end

      def resource_path(object)
        "/#{@bucket_name}/#{object}"
      end

      def mock_objects(objects, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListBucketResult {
            {
              :prefix => 'Prefix',
              :delimiter => 'Delimiter',
              :limit => 'MaxKeys',
              :marker => 'Marker',
              :next_marker => 'NextMarker',
              :truncated => 'IsTruncated',
              :encoding => 'EncodingType'
            }.map do |k, v|
              xml.send(v, more[k]) if more[k] != nil
            end

            objects.each do |o|
              xml.Contents {
                xml.Key o.key
                xml.Size o.size
                xml.ETag o.etag
              }
            end

            (more[:common_prefixes] || []).each do |p|
              xml.CommonPrefixes {
                xml.Prefix p
              }
            end
          }
        end.to_xml
      end

      def mock_uploads(txns, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListMultipartUploadsResult {
            {
              :prefix => 'Prefix',
              :delimiter => 'Delimiter',
              :limit => 'MaxUploads',
              :key_marker => 'KeyMarker',
              :id_marker => 'UploadIdMarker',
              :next_key_marker => 'NextKeyMarker',
              :next_id_marker => 'NextUploadIdMarker',
              :truncated => 'IsTruncated',
              :encoding => 'EncodingType'
            }.map do |k, v|
              xml.send(v, more[k]) if more[k] != nil
            end

            txns.each do |t|
              xml.Upload {
                xml.Key t.object
                xml.UploadId t.id
              }
            end
          }
        end.to_xml
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

      context "bucket operations" do
        it "should get acl" do
          query = {'acl' => nil}
          return_acl = ACL::PUBLIC_READ

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl))

          acl = @bucket.acl

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)
          expect(acl).to eq(return_acl)
        end

        it "should set acl" do
          query = {'acl' => nil}

          stub_request(:put, bucket_url).with(:query => query)

          @bucket.acl = ACL::PUBLIC_READ

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => nil)
        end

        it "should delete logging setting" do
          query = {'logging' => nil}

          stub_request(:delete, bucket_url).with(:query => query)

          @bucket.logging = BucketLogging.new(:enable => false)

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:query => query, :body => nil)
        end

        it "should set logging setting" do
          query = {'logging' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.BucketLoggingStatus {
              xml.LoggingEnabled {
                xml.TargetBucket 'target-bucket'
              }
            }
            end.to_xml

          stub_request(:put, bucket_url).with(:query => query)

          @bucket.logging = BucketLogging.new(:enable => true, :target_bucket => 'target-bucket')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

        it "should get logging setting" do
          query = {'logging' => nil}

          retbody = Nokogiri::XML::Builder.new do |xml|
            xml.BucketLoggingStatus {
              xml.LoggingEnabled {
                xml.TargetBucket 'target-bucket'
                xml.TargetPrefix 'target-prefix'
              }
            }
            end.to_xml

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => retbody)

          logging = @bucket.logging

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)
          expect(logging.enable).to eq(true)
          expect(logging.target_bucket).to eq('target-bucket')

        end

        it "should set webseit" do
          query = {'website' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.WebsiteConfiguration {
              xml.IndexDocument {
                xml.Suffix 'index.html'
              }
            }
            end.to_xml

          stub_request(:put, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => nil)

          @bucket.website = BucketWebsite.new(:enable => true, :index => 'index.html')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

        it "should delete webseit" do
          query = {'website' => nil}

          stub_request(:delete, bucket_url)
            .with(:query => query)
            .to_return(status: 204, :body => nil)

          @bucket.website = BucketWebsite.new(:enable => false)

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:query => query, :body => nil)
        end

        it "should get webseit" do
          query = {'website' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.WebsiteConfiguration {
              xml.IndexDocument {
                xml.Suffix 'index.html'
              }
              xml.ErrorDocument {
                xml.Key 'error.html'
              }
            }
            end.to_xml

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => body)

          website = @bucket.website

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)

          expect(website.enable).to eq(true)
          expect(website.index).to eq('index.html')
          expect(website.error).to eq('error.html')
        end

        it "should set referer" do
          query = {'referer' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.RefererConfiguration {
              xml.AllowEmptyReferer 'true'
              xml.RefererList {
                xml.Referer 'http://www.aliyun.com'
              }
            }
            end.to_xml

          stub_request(:put, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => nil)

          @bucket.referer = BucketReferer.new(:allow_empty => true, :whitelist => ['http://www.aliyun.com'])

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

        it "should get referer" do
          query = {'referer' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.RefererConfiguration {
              xml.AllowEmptyReferer 'true'
              xml.RefererList {
                xml.Referer 'http://www.aliyun.com'
              }
            }
            end.to_xml

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => body)

          referer = @bucket.referer

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)

          expect(referer.allow_empty).to eq(true)
          expect(referer.whitelist).to eq(['http://www.aliyun.com'])
        end

        it "should set cors" do
          query = {'cors' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.CORSConfiguration {
              xml.CORSRule {
                xml.AllowedOrigin '*'
                xml.AllowedMethod 'PUT'
                xml.AllowedHeader 'Authorization'
              }
            }
            end.to_xml

          stub_request(:put, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => nil)

          rules = [
            CORSRule.new(
              :allowed_origins => ['*'],
              :allowed_methods => ['PUT'],
              :allowed_headers => ['Authorization'],
              :expose_headers =>[])
          ]

          @bucket.cors = rules

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

        it "should delete cors" do
          query = {'cors' => nil}

          stub_request(:delete, bucket_url)
            .with(:query => query)
            .to_return(status: 204, :body => nil)

          @bucket.cors = []

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:query => query, :body => nil)
        end

        it "should get cors" do
          query = {'cors' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.CORSConfiguration {
              xml.CORSRule {
                xml.AllowedOrigin '*'
                xml.AllowedMethod 'PUT'
                xml.AllowedHeader 'Authorization'
              }
            }
            end.to_xml

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => body)

          cors = @bucket.cors

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)
        end

		it "should set versioning" do
          query = {'versioning' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.VersioningConfiguration {
              xml.Status 'Enabled'
            }
            end.to_xml

          stub_request(:put, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => nil)

          @bucket.versioning = BucketVersioning.new(:status => 'Enabled')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

		it "should get versioning" do
          query = {'versioning' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.VersioningConfiguration {
              xml.Status 'Enabled'
            }
            end.to_xml

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => body)

          ret = @bucket.versioning

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)

          expect(ret.status).to eq('Enabled')
        end

		it "should set encryption with aes256" do
          query = {'encryption' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.ServerSideEncryptionRule {
              xml.ApplyServerSideEncryptionByDefault {
                xml.SSEAlgorithm 'AES256'
              }
            }
            end.to_xml

          stub_request(:put, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => nil)

          @bucket.encryption = BucketEncryption.new(:enable => true, :sse_algorithm => 'AES256')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

		it "should set encryption with KMS" do
          query = {'encryption' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.ServerSideEncryptionRule {
              xml.ApplyServerSideEncryptionByDefault {
                xml.SSEAlgorithm 'KMS'
                xml.KMSMasterKeyID 'kms-id'
              }
            }
            end.to_xml

          stub_request(:put, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => nil)

          @bucket.encryption = BucketEncryption.new(
			:enable => true, 
			:sse_algorithm => 'KMS', 
			:kms_master_key_id => 'kms-id')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:query => query, :body => body)
        end

		it "should get encryption" do
          query = {'encryption' => nil}

          body = Nokogiri::XML::Builder.new do |xml|
            xml.ServerSideEncryptionRule {
              xml.ApplyServerSideEncryptionByDefault {
                xml.SSEAlgorithm 'KMS'
                xml.KMSMasterKeyID 'kms-id'
              }
            }
            end.to_xml

          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(status: 200, :body => body)

          ret = @bucket.encryption

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil)

          expect(ret.sse_algorithm).to eq('KMS')
          expect(ret.kms_master_key_id).to eq('kms-id')
        end

		it "should delete encryption" do
          query = {'encryption' => nil}

          stub_request(:delete, bucket_url)
            .with(:query => query)
            .to_return(status: 204, :body => nil)

          @bucket.encryption = BucketEncryption.new(:enable => false)

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:query => query, :body => nil)
        end

        it "should get bucket url" do
          expect(@bucket.bucket_url)
            .to eq('http://rubysdk-bucket.oss-cn-hangzhou.aliyuncs.com/')
        end

        it "should get access key id" do
          expect(@bucket.access_key_id).to eq('xxx')
        end
      end # bucket operations

      context "object operations" do
        it "should list objects" do
          query_1 = {
            :prefix => 'list-',
            :delimiter => '-',
            'encoding-type' => 'url'
          }
          return_obj_1 = (1..5).map{ |i| Object.new(
            :key => "obj-#{i}",
            :size => 1024 * i,
            :etag => "etag-#{i}")}
          return_more_1 = {
            :next_marker => 'foo',
            :truncated => true,
            :common_prefixes => ['hello', 'world']
          }

          query_2 = {
            :prefix => 'list-',
            :delimiter => '-',
            :marker => 'foo',
            'encoding-type' => 'url'
          }
          return_obj_2 = (6..8).map{ |i| Object.new(
            :key => "obj-#{i}",
            :size => 1024 * i,
            :etag => "etag-#{i}")}
          return_more_2 = {
            :next_marker => 'bar',
            :truncated => false,
            :common_prefixes => ['rock', 'suck']
          }

          stub_request(:get, bucket_url)
            .with(:query => query_1)
            .to_return(:body => mock_objects(return_obj_1, return_more_1))

          stub_request(:get, bucket_url)
            .with(:query => query_2)
            .to_return(:body => mock_objects(return_obj_2, return_more_2))

          list = @bucket.list_objects :prefix => 'list-', :delimiter => '-'
          all = list.to_a

          expect(WebMock).to have_requested(:get, bucket_url)
                         .with(:query => query_1).times(1)
          expect(WebMock).to have_requested(:get, bucket_url)
                         .with(:query => query_2).times(1)

          objs = all.select{ |x| x.is_a?(Object) }
          common_prefixes = all.select{ |x| x.is_a?(String) }
          all_objs = (1..8).map{ |i| Object.new(
            :key => "obj-#{i}",
            :size => 1024 * i,
            :etag => "etag-#{i}")}
          expect(objs.map{ |o| o.to_s }).to match_array(all_objs.map{ |o| o.to_s })
          all_prefixes = ['hello', 'world', 'rock', 'suck']
          expect(common_prefixes).to match_array(all_prefixes)
        end

        it "should put object from file" do
          key = 'ruby'
          stub_request(:put, object_url(key))

          content = (1..10).map{ |i| i.to_s.rjust(9, '0') }.join("\n")
          File.open('/tmp/x', 'w'){ |f| f.write(content) }

          @bucket.put_object(key, :file => '/tmp/x')

          expect(WebMock).to have_requested(:put, object_url(key))
            .with(:body => content, :query => {})
        end

        it "should put object with acl" do
          key = 'ruby'
          stub_request(:put, object_url(key))

          @bucket.put_object(key, :acl => ACL::PUBLIC_READ)

          expect(WebMock)
            .to have_requested(:put, object_url(key))
                 .with(:headers => {'X-Oss-Object-Acl' => ACL::PUBLIC_READ})
        end

        it "should put object with callback" do
          key = 'ruby'
          stub_request(:put, object_url(key))

          callback = Callback.new(
            url: 'http://app.server.com/callback',
            query: {'id' => 1, 'name' => '杭州'},
            body: 'hello world',
            host: 'server.com'
          )
          @bucket.put_object(key, callback: callback)

          expect(WebMock).to have_requested(:put, object_url(key))
            .with { |req| req.headers.key?('X-Oss-Callback') }
        end

        it "should raise CallbackError when callback failed" do
          key = 'ruby'
          code = 'CallbackFailed'
          message = 'Error status: 502.'
          stub_request(:put, object_url(key))
            .to_return(:status => 203, :body => mock_error(code, message))

          callback = Callback.new(
            url: 'http://app.server.com/callback',
            query: {'id' => 1, 'name' => '杭州'},
            body: 'hello world',
            host: 'server.com'
          )
          expect {
            @bucket.put_object(key, callback: callback)
          }.to raise_error(CallbackError, err(message))

          expect(WebMock).to have_requested(:put, object_url(key))
            .with { |req| req.headers.key?('X-Oss-Callback') }
        end

        it "should set custom headers when put object" do
          key = 'ruby'
          stub_request(:put, object_url(key))

          @bucket.put_object(
            key, headers: {'cache-control' => 'xxx', 'expires' => 'yyy'})

          headers = {}
          expect(WebMock).to have_requested(:put, object_url(key))
                              .with { |req| headers = req.headers }
          expect(headers['Cache-Control']).to eq('xxx')
          expect(headers['Expires']).to eq('yyy')
        end

        it "should set custom headers when append object" do
          key = 'ruby'
          query = {'append' => nil, 'position' => 11}
          stub_request(:post, object_url(key)).with(:query => query)

          @bucket.append_object(
            key, 11,
            headers: {'CACHE-CONTROL' => 'nocache', 'EXPIRES' => 'seripxe'})

          headers = {}
          expect(WebMock).to have_requested(:post, object_url(key))
                              .with(:query => query)
                              .with { |req| headers = req.headers }
          expect(headers['Cache-Control']).to eq('nocache')
          expect(headers['Expires']).to eq('seripxe')
        end

        it "should get object to file" do
          key = 'ruby'
          # 100 KB
          content = (1..1024).map{ |i| i.to_s.rjust(99, '0') }.join(",")

          stub_request(:get, object_url(key)).to_return(:body => content)

          @bucket.get_object(key, :file => '/tmp/x')

          expect(WebMock).to have_requested(:get, object_url(key))
                         .with(:body => nil, :query => {})
          expect(File.read('/tmp/x')).to eq(content)
        end

        it "should only get meta when get object without :file or block" do
          key = 'ruby'

          last_modified = Time.now.rfc822
          return_headers = {
            'x-oss-object-type' => 'Normal',
            'ETag' => 'xxxyyyzzz',
            'Content-Length' => 1024,
            'Last-Modified' => last_modified,
            'x-oss-meta-year' => '2015',
            'x-oss-meta-people' => 'mary'
          }
          stub_request(:head, object_url(key))
            .to_return(:headers => return_headers)

          obj = @bucket.get_object(key)

          expect(WebMock).to have_requested(:head, object_url(key))
            .with(:body => nil, :query => {})

          expect(obj.key).to eq(key)
          expect(obj.type).to eq('Normal')
          expect(obj.etag).to eq('xxxyyyzzz')
          expect(obj.size).to eq(1024)
          expect(obj.last_modified.rfc822).to eq(last_modified)
          expect(obj.metas).to eq({'year' => '2015', 'people' => 'mary'})
        end

        it "should append object from file" do
          key = 'ruby'
          query = {'append' => nil, 'position' => 11}
          stub_request(:post, object_url(key)).with(:query => query)

          content = (1..10).map{ |i| i.to_s.rjust(9, '0') }.join("\n")
          content = "<html>" + content + "</html>"
          File.open('/tmp/x.html', 'w'){ |f| f.write(content) }

          @bucket.append_object(key, 11, :file => '/tmp/x.html')

          expect(WebMock).to have_requested(:post, object_url(key))
                         .with(:query => query, :body => content,
                               :headers => {'Content-Type' => 'text/html'})
        end

        it "should append object with acl" do
          key = 'ruby'
          query = {'append' => nil, 'position' => 11}
          stub_request(:post, object_url(key)).with(:query => query)

          @bucket.append_object(key, 11, :acl => ACL::PUBLIC_READ_WRITE)

          expect(WebMock)
            .to have_requested(:post, object_url(key))
                 .with(:query => query,
                       :headers => {'X-Oss-Object-Acl' => ACL::PUBLIC_READ_WRITE})
        end

        it "should answer object exists?" do
          key = 'ruby'

          stub_request(:head, object_url(key))
            .to_return(:status => 404).times(3)

          expect {
            @bucket.get_object(key)
          }.to raise_error(ServerError, err("UnknownError[404].", ''))

          expect(@bucket.object_exists?(key)).to be false
          expect(@bucket.object_exist?(key)).to be false

          last_modified = Time.now.rfc822
          return_headers = {
            'x-oss-object-type' => 'Normal',
            'ETag' => 'xxxyyyzzz',
            'Content-Length' => 1024,
            'Last-Modified' => last_modified,
            'x-oss-meta-year' => '2015',
            'x-oss-meta-people' => 'mary'
          }

          stub_request(:head, object_url(key))
            .to_return(:headers => return_headers).times(2)

          expect(@bucket.object_exists?(key)).to be true
          expect(@bucket.object_exist?(key)).to be true

          stub_request(:head, object_url(key))
            .to_return(:status => 500)

          expect {
            @bucket.object_exists?(key)
          }.to raise_error(ServerError, err("UnknownError[500].", ''))
        end

        it "should update object metas" do
          key = 'ruby'

          stub_request(:put, object_url(key))

          @bucket.update_object_metas(
            key, {'people' => 'mary', 'year' => '2016'})

          expect(WebMock).to have_requested(:put, object_url(key))
                         .with(:body => nil,
                               :headers => {
                                 'x-oss-copy-source' => resource_path(key),
                                 'x-oss-metadata-directive' => 'REPLACE',
                                 'x-oss-meta-year' => '2016',
                                 'x-oss-meta-people' => 'mary'})
        end

        it "should get object url" do
          url = @bucket.object_url('yeah', false)
          object_url = 'http://rubysdk-bucket.oss-cn-hangzhou.aliyuncs.com/yeah'
          expect(url).to eq(object_url)

          url = @bucket.object_url('yeah')
          path = url[0, url.index('?')]
          expect(path).to eq(object_url)

          query = {}
          url[url.index('?') + 1, url.size].split('&')
            .each { |s| k, v = s.split('='); query[k] = v }

          expect(query.key?('Expires')).to be true
          expect(query['OSSAccessKeyId']).to eq('xxx')
          expires = query['Expires']
          signature = CGI.unescape(query['Signature'])

          string_to_sign =
            "GET\n" + "\n\n" + "#{expires}\n" + "/rubysdk-bucket/yeah"
          sig = Util.sign('yyy', string_to_sign)
          expect(signature).to eq(sig)
        end

        context 'should use STS' do
          it "get object url" do
            sts_bucket = Client.new(
              :endpoint => @endpoint,
              :access_key_id => 'xxx',
              :access_key_secret => 'yyy',
              :sts_token => 'zzz').get_bucket(@bucket_name)

            object_url = 'http://rubysdk-bucket.oss-cn-hangzhou.aliyuncs.com/yeah'

            url = sts_bucket.object_url('yeah')
            path = url[0, url.index('?')]
            expect(path).to eq(object_url)

            query = {}
            url[url.index('?') + 1, url.size].split('&')
              .each { |s| k, v = s.split('='); query[k] = v }

            expect(query.key?('Expires')).to be true
            expect(query.key?('Signature')).to be true
            expect(query['OSSAccessKeyId']).to eq('xxx')
            expect(query['security-token']).to eq('zzz')
          end

          it "get object url with query string" do
            sts_bucket = Client.new(
              :endpoint => @endpoint,
              :access_key_id => 'xxx',
              :access_key_secret => 'yyy',
              :sts_token => 'zzz').get_bucket(@bucket_name)

            param = {
              'x-oss-process' => 'image/resize,m_fill,h_100,w_100',
            }  
            url = sts_bucket.object_url('ico.png', true, 60, param)
            path = url[0, url.index('?')]
            expect(path).to eq('http://rubysdk-bucket.oss-cn-hangzhou.aliyuncs.com/ico.png')

            query = {}
            url[url.index('?') + 1, url.size].split('&')
              .each { |s| k, v = s.split('='); query[k] = v }

            expect(query.key?('Expires')).to be true
            expect(query.key?('Signature')).to be true
            expect(query['OSSAccessKeyId']).to eq('xxx')
            expect(query['security-token']).to eq('zzz')
            expect(query['x-oss-process']).to eq('image%2Fresize%2Cm_fill%2Ch_100%2Cw_100')
          end
        end
      end # object operations

      context "multipart operations" do
        it "should list uploads" do
          query_1 = {
            :prefix => 'list-',
            'encoding-type' => 'url',
            'uploads' => nil
          }
          return_up_1 = (1..5).map{ |i| Multipart::Transaction.new(
            :id => "txn-#{i}",
            :object => "my-object",
            :bucket => @bucket_name
          )}
          return_more_1 = {
            :next_id_marker => "txn-5",
            :truncated => true
          }

          query_2 = {
            :prefix => 'list-',
            'upload-id-marker' => 'txn-5',
            'encoding-type' => 'url',
            'uploads' => nil
          }
          return_up_2 = (6..8).map{ |i| Multipart::Transaction.new(
            :id => "txn-#{i}",
            :object => "my-object",
            :bucket => @bucket_name
          )}
          return_more_2 = {
            :next_id_marker => 'txn-8',
            :truncated => false,
          }

          stub_request(:get, bucket_url)
            .with(:query => query_1)
            .to_return(:body => mock_uploads(return_up_1, return_more_1))

          stub_request(:get, bucket_url)
            .with(:query => query_2)
            .to_return(:body => mock_uploads(return_up_2, return_more_2))

          txns = @bucket.list_uploads(prefix: 'list-').to_a

          expect(WebMock).to have_requested(:get, bucket_url)
                         .with(:query => query_1).times(1)
          expect(WebMock).to have_requested(:get, bucket_url)
                         .with(:query => query_2).times(1)

          all_txns = (1..8).map{ |i| Multipart::Transaction.new(
            :id => "txn-#{i}",
            :object => "my-object",
            :bucket => @bucket_name
          )}
          expect(txns.map(&:to_s)).to match_array(all_txns.map(&:to_s))
        end
      end # multipart operations

      context "crc" do
        it "should download crc enable equal config setting" do
          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => 'true').get_bucket(@bucket_name)
          expect(bucket.download_crc_enable).to eq(true)

          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => true).get_bucket(@bucket_name)
          expect(bucket.download_crc_enable).to eq(true)

          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => 'false').get_bucket(@bucket_name)
          expect(bucket.download_crc_enable).to eq(false)

          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :download_crc_enable => false).get_bucket(@bucket_name)
          expect(bucket.download_crc_enable).to eq(false)

          # check default value
          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy').get_bucket(@bucket_name)
          expect(bucket.download_crc_enable).to eq(false)
        end

        it "should upload crc enable equal config setting" do
          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => 'true').get_bucket(@bucket_name)
          expect(bucket.upload_crc_enable).to eq(true)

          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => true).get_bucket(@bucket_name)
          expect(bucket.upload_crc_enable).to eq(true)

          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => 'false').get_bucket(@bucket_name)
          expect(bucket.upload_crc_enable).to eq(false)

          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy',
                      :upload_crc_enable => false).get_bucket(@bucket_name)
          expect(bucket.upload_crc_enable).to eq(false)

          # check default value
          bucket = Client.new(
                      :endpoint => @endpoint,
                      :access_key_id => 'xxx', :access_key_secret => 'yyy').get_bucket(@bucket_name)
          expect(bucket.upload_crc_enable).to eq(true)
        end
      end # crc

    end # Bucket
  end # OSS
end # Aliyun
