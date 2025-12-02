# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe Client do

      context "construct" do
        it "should setup endpoint and a/k" do
          endpoint = 'oss-cn-hangzhou.aliyuncs.com'
          client = Client.new(
            :endpoint => endpoint,
            :access_key_id => 'xxx ', :access_key_secret => '  yyy ',
            :sts_token => 'sts-token')

          config = client.instance_variable_get('@config')
          expect(config.endpoint.to_s).to eq("http://#{endpoint}")
          expect(config.access_key_id).to eq('xxx')
          expect(config.access_key_secret).to eq('yyy')
          expect(config.sts_token).to eq('sts-token')
        end

        it "should work with CNAME endpoint" do
          endpoint = 'rockuw.com'
          bucket = 'rubysdk-bucket'
          object = 'rubysdk-object'
          client = Client.new(
            access_key_id: 'xxx',
            access_key_secret: 'yyy',
            endpoint: endpoint,
            cname: true)

          # TODO: ignore queries here
          # bucket operations
          stub_request(:get, endpoint)
            .with(:query => {'encoding-type' => 'url'})
          client.get_bucket(bucket).list_objects.take(1)
          expect(WebMock)
            .to have_requested(:get, endpoint)
                 .with(:query => {'encoding-type' => 'url'})

          # object operations
          stub_request(:get, "#{endpoint}/#{object}")
          client.get_bucket(bucket).get_object(object) {}
          expect(WebMock).to have_requested(:get, "#{endpoint}/#{object}")
        end

        it "should work with IP endpoint" do
          endpoint = 'http://127.0.0.1:3000'
          bucket = 'rubysdk-bucket'
          object = 'rubysdk-object'
          client = Client.new(
            access_key_id: 'xxx',
            access_key_secret: 'yyy',
            endpoint: endpoint)

          # TODO: ignore queries here
          # bucket operations
          stub_request(:get, "#{endpoint}/#{bucket}/")
            .with(:query => {'encoding-type' => 'url'})
          client.get_bucket(bucket).list_objects.take(1)
          expect(WebMock)
            .to have_requested(:get, "#{endpoint}/#{bucket}/")
                 .with(:query => {'encoding-type' => 'url'})

          # object operations
          stub_request(:get, "#{endpoint}/#{bucket}/#{object}")
          client.get_bucket(bucket).get_object(object) {}
          expect(WebMock).to have_requested(:get, "#{endpoint}/#{bucket}/#{object}")
        end

        it "should not set Authorization with anonymous client" do
          endpoint = 'oss-cn-hangzhou.aliyuncs.com'
          bucket = 'rubysdk-bucket'
          object = 'rubysdk-object'
          client = Client.new(:endpoint => endpoint)

          stub_request(:get, "#{bucket}.#{endpoint}/#{object}")

          client.get_bucket(bucket).get_object(object) {}

          expect(WebMock)
            .to have_requested(:get, "#{bucket}.#{endpoint}/#{object}")
            .with{ |req| not req.headers.has_key?('Authorization') }
        end

        it "should set STS header" do
          endpoint = 'oss-cn-hangzhou.aliyuncs.com'
          bucket = 'rubysdk-bucket'
          object = 'rubysdk-object'
          client = Client.new(
            :endpoint => endpoint,
            :access_key_id => 'xxx', :access_key_secret => 'yyy',
            :sts_token => 'sts-token')

          stub_request(:get, "#{bucket}.#{endpoint}/#{object}")

          client.get_bucket(bucket).get_object(object) {}

          expect(WebMock)
            .to have_requested(:get, "#{bucket}.#{endpoint}/#{object}")
            .with{ |req| req.headers.key?('X-Oss-Security-Token') }
        end

        it "should construct different client" do
          bucket = 'rubysdk-bucket'
          object = 'rubysdk-object'
          ep1 = 'oss-cn-hangzhou.aliyuncs.com'
          c1 = Client.new(
            :endpoint => ep1,
            :access_key_id => 'xxx', :access_key_secret => 'yyy')
          ep2 = 'oss-cn-beijing.aliyuncs.com'
          c2 = Client.new(
            :endpoint => ep2,
            :access_key_id => 'aaa', :access_key_secret => 'bbb')

          stub_request(:get, "#{bucket}.#{ep1}/#{object}")
          stub_request(:put, "#{bucket}.#{ep2}/#{object}")

          c1.get_bucket(bucket).get_object(object) {}
          c2.get_bucket(bucket).put_object(object)

          expect(WebMock).to have_requested(:get, "#{bucket}.#{ep1}/#{object}")
          expect(WebMock).to have_requested(:put, "#{bucket}.#{ep2}/#{object}")
        end

        it "should fail with invalid bucket name" do
          bucket = 'INVALID'
          ep1 = 'oss-cn-hangzhou.aliyuncs.com'
          client = Client.new(
            :endpoint => ep1,
            :access_key_id => 'xxx', :access_key_secret => 'yyy')

          expect {
            client.create_bucket(bucket)
          }.to raise_error(ClientError, "The bucket name is invalid.")

          expect {
            client.delete_bucket(bucket)
          }.to raise_error(ClientError, "The bucket name is invalid.")

          expect {
            client.bucket_exists?(bucket)
          }.to raise_error(ClientError, "The bucket name is invalid.")

          expect {
            client.get_bucket(bucket)
          }.to raise_error(ClientError, "The bucket name is invalid.")
        end

      end # construct

      def mock_buckets(buckets, more = {})
        Nokogiri::XML::Builder.new do |xml|
          xml.ListAllMyBucketsResult {
            xml.Owner {
              xml.ID 'owner_id'
              xml.DisplayName 'owner_name'
            }
            xml.Buckets {
              buckets.each do |b|
                xml.Bucket {
                  xml.Location b.location
                  xml.Name b.name
                  xml.CreationDate b.creation_time.to_s
                }
              end
            }

            unless more.empty?
              xml.Prefix more[:prefix]
              xml.Marker more[:marker]
              xml.MaxKeys more[:limit].to_s
              xml.NextMarker more[:next_marker]
              xml.IsTruncated more[:truncated]
            end
          }
        end.to_xml
      end

      def mock_location(location)
        Nokogiri::XML::Builder.new do |xml|
          xml.CreateBucketConfiguration {
            xml.LocationConstraint location
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

      context "bucket operations" do
        before :all do
          @endpoint = 'oss.aliyuncs.com'
          @client = Client.new(
            :endpoint => @endpoint,
            :access_key_id => 'xxx',
            :access_key_secret => 'yyy')
          @bucket = 'rubysdk-bucket'
        end

        def bucket_url
          @bucket + "." + @endpoint
        end

        it "should create bucket" do
          location = 'oss-cn-hangzhou'

          stub_request(:put, bucket_url).with(:body => mock_location(location))

          @client.create_bucket(@bucket, :location => 'oss-cn-hangzhou')

          expect(WebMock).to have_requested(:put, bucket_url)
            .with(:body => mock_location(location), :query => {})
        end

        it "should delete bucket" do
          stub_request(:delete, bucket_url)

          @client.delete_bucket(@bucket)

          expect(WebMock).to have_requested(:delete, bucket_url)
            .with(:body => nil, :query => {})
        end

        it "should paging list buckets" do
          return_buckets_1 = (1..5).map do |i|
            name = "rubysdk-bucket-#{i.to_s.rjust(3, '0')}"
            Bucket.new(
              :name => name,
              :location => 'oss-cn-hangzhou',
              :creation_time => Time.now)
          end

          more_1 = {:next_marker => return_buckets_1.last.name, :truncated => true}

          return_buckets_2 = (6..10).map do |i|
            name = "rubysdk-bucket-#{i.to_s.rjust(3, '0')}"
            Bucket.new(
              :name => name,
              :location => 'oss-cn-hangzhou',
              :creation_time => Time.now)
          end

          more_2 = {:truncated => false}

          stub_request(:get, /#{@endpoint}.*/)
            .to_return(:body => mock_buckets(return_buckets_1, more_1)).then
            .to_return(:body => mock_buckets(return_buckets_2, more_2))

          buckets = @client.list_buckets

          expect(buckets.map {|b| b.to_s}.join(";"))
            .to eq((return_buckets_1 + return_buckets_2).map {|b| b.to_s}.join(";"))
          expect(WebMock).to have_requested(:get, /#{@endpoint}.*/).times(2)
        end

        it "should test bucket existence" do
          query = {'acl' => nil}
          return_acl = ACL::PUBLIC_READ
          stub_request(:get, bucket_url)
            .with(:query => query)
            .to_return(:body => mock_acl(return_acl)).then
            .to_return(:status => 404)

          exist = @client.bucket_exists?(@bucket)
          expect(exist).to be true

          exist = @client.bucket_exists?(@bucket)
          expect(exist).to be false

          expect(WebMock).to have_requested(:get, bucket_url)
            .with(:query => query, :body => nil).times(2)
        end

        it "should not list buckets when endpoint is cname" do
          cname_client = Client.new(
            :endpoint => @endpoint,
            :access_key_id => 'xxx',
            :access_key_secret => 'yyy',
            :cname => true)

          expect {
            cname_client.list_buckets
          }.to raise_error(ClientError)
        end

        it "should use HTTPS" do
          stub_request(:put, "https://#{bucket_url}")

          https_client = Client.new(
            :endpoint => "https://#{@endpoint}",
            :access_key_id => 'xxx',
            :access_key_secret => 'yyy',
            :cname => false)

          https_client.create_bucket(@bucket)

          expect(WebMock).to have_requested(:put, "https://#{bucket_url}")
        end
      end # bucket operations

    end # Client

  end # OSS
end # Aliyun
