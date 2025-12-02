# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module OSS

    describe "Service" do
      before :all do
        @endpoint = 'oss.aliyuncs.com'
        @protocol = Protocol.new(
          Config.new(:endpoint => @endpoint,
                     :access_key_id => 'xxx', :access_key_secret => 'yyy'))

        @all_buckets = []
        (1..10).each do |i|
          name = "rubysdk-bucket-#{i.to_s.rjust(3, '0')}"
          @all_buckets << Bucket.new(
            :name => name,
            :location => 'oss-cn-hangzhou',
            :creation_time => Time.now)
        end
      end

      # 生成list_buckets返回的响应，包含bucket列表和more信息
      def mock_response(buckets, more)
        builder = Nokogiri::XML::Builder.new do |xml|
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
        end

        builder.to_xml
      end

      context "List all buckets" do
        # 测试list_buckets正确地发送了HTTP请求
        it "should send correct request" do
          stub_request(:get, @endpoint)

          @protocol.list_buckets

          expect(WebMock).to have_requested(:get, @endpoint).
                              with(:body => nil, :query => {})
        end

        # 测试list_buckets正确地解析了list_buckets的返回
        it "should correctly parse response" do
          stub_request(:get, @endpoint).to_return(
            {:body => mock_response(@all_buckets, {})})

          buckets, more = @protocol.list_buckets
          bucket_names = buckets.map {|b| b.name}

          all_bucket_names = @all_buckets.map {|b| b.name}
          expect(bucket_names).to match_array(all_bucket_names)

          expect(more).to be_empty
        end
      end

      context "Paging buckets" do
        # 测试list_buckets的请求中包含prefix/marker/maxkeys等信息
        it "should set prefix/max-keys param" do
          prefix = 'rubysdk-bucket-00'
          marker = 'rubysdk-bucket-002'
          limit = 5

          stub_request(:get, @endpoint).with(
            :query => {'prefix' => prefix, 'marker' => marker, 'max-keys' => limit})

          @protocol.list_buckets(
            :prefix => prefix, :limit => limit, :marker => marker)

          expect(WebMock).to have_requested(:get, @endpoint).
            with(:body => nil,
                 :query => {'prefix' => prefix,
                            'marker' => marker,
                            'max-keys' => limit})
        end

        # 测试list_buckets正确地解析了HTTP响应，包含more信息
        it "should parse next marker" do
          prefix = 'rubysdk-bucket-00'
          marker = 'rubysdk-bucket-002'
          limit = 5
          # returns ['rubysdk-bucket-003', ..., 'rubysdk-bucket-007']
          return_buckets = @all_buckets[2, 5]
          next_marker = 'rubysdk-bucket-007'

          more = {:prefix => prefix, :marker => marker, :limit => limit,
                  :next_marker => next_marker, :truncated => true}

          stub_request(:get, @endpoint).with(
            :query => {'prefix' => prefix, 'marker' => marker, 'max-keys' => limit}
          ).to_return(
            {:body => mock_response(return_buckets, more)})

          buckets, more = @protocol.list_buckets(
                     :prefix => prefix,
                     :limit => limit,
                     :marker => marker)

          bucket_names = buckets.map {|b| b.name}
          return_bucket_names = return_buckets.map {|b| b.name}
          expect(bucket_names).to match_array(return_bucket_names)

          expect(more).to eq({
            :prefix => prefix,
            :marker => marker,
            :limit => limit,
            :next_marker => next_marker,
            :truncated => true})
        end

      end

    end # Bucket
  end # OSS
end # Aliyun
