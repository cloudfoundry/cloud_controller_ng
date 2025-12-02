require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module STS

    describe Client do

      context "construct" do
        it "should setup a/k" do
          client = Client.new(
            :access_key_id => ' xxx', :access_key_secret => ' yyy ')

          config = client.instance_variable_get('@config')
          expect(config.access_key_id).to eq('xxx')
          expect(config.access_key_secret).to eq('yyy')
        end
      end

      def mock_sts(id, key, token, expiration)
        Nokogiri::XML::Builder.new do |xml|
          xml.AssumeRoleResponse {
            xml.RequestId '0000'
            xml.AssumedRoleUser {
              xml.arn 'arn-001'
              xml.AssumedRoleUserId 'id-001'
            }
            xml.Credentials {
              xml.AccessKeyId id
              xml.AccessKeySecret key
              xml.SecurityToken token
              xml.Expiration expiration.utc.iso8601
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

      before :all do
        @url = 'https://sts.aliyuncs.com'
        @client = Client.new(access_key_id: 'xxx', access_key_secret: 'yyy')
      end

      context "assume role" do
        it "should assume role" do
          expiration = Time.parse(Time.now.utc.iso8601)

          stub_request(:post, @url)
            .to_return(:body => mock_sts(
                         'sts_id', 'sts_key', 'sts_token', expiration))

          token = @client.assume_role('role-1', 'app-1')

          rbody = nil
          expect(WebMock).to have_requested(:post, @url)
                              .with { |req| rbody = req.body }
          params = rbody.split('&').reduce({}) { |h, i|
            v = i.split('=')
            h.merge({v[0] => v[1]})
          }
          expect(params['Action']).to eq('AssumeRole')
          expect(params['RoleArn']).to eq('role-1')
          expect(params['RoleSessionName']).to eq('app-1')
          expect(params['DurationSeconds']).to eq('3600')
          expect(params['Format']).to eq('XML')
          expect(params['Version']).to eq('2015-04-01')
          expect(params['AccessKeyId']).to eq('xxx')
          expect(params.key?('Signature')).to be true
          expect(params.key?('SignatureNonce')).to be true
          expect(params['SignatureMethod']).to eq('HMAC-SHA1')

          expect(token.access_key_id).to eq('sts_id')
          expect(token.access_key_secret).to eq('sts_key')
          expect(token.security_token).to eq('sts_token')
          expect(token.expiration).to eq(expiration)
        end

        it "should raise error" do
          code = "InvalidParameter"
          message = "Bla bla bla."

          stub_request(:post, @url)
            .to_return(:status => 400,
                       :body => mock_error(code, message))


          expect {
            @client.assume_role('role-1', 'app-1')
          }.to raise_error(ServerError, err(message))

        end

        it "should set policy and duration" do
          expiration = Time.parse(Time.now.utc.iso8601)

          stub_request(:post, @url)
            .to_return(:body => mock_sts(
                         'sts_id', 'sts_key', 'sts_token', expiration))

          policy = Policy.new
          policy.allow(
            ['oss:Get*', 'oss:PutObject'],
            ['acs:oss:*:*:bucket', 'acs::oss:*:*:bucket/*'])
          duration = 300
          token = @client.assume_role('role-1', 'app-1', policy, duration)

          rbody = nil
          expect(WebMock).to have_requested(:post, @url)
                              .with { |req| rbody = req.body }
          params = rbody.split('&').reduce({}) { |h, i|
            v = i.split('=')
            h.merge({v[0] => CGI.unescape(v[1])})
          }
          expect(params['Action']).to eq('AssumeRole')
          expect(params['RoleArn']).to eq('role-1')
          expect(params['RoleSessionName']).to eq('app-1')
          expect(params['DurationSeconds']).to eq('300')
          expect(params['Format']).to eq('XML')
          expect(params['Version']).to eq('2015-04-01')
          expect(params['AccessKeyId']).to eq('xxx')
          expect(params.key?('Signature')).to be true
          expect(params.key?('SignatureNonce')).to be true
          expect(params['SignatureMethod']).to eq('HMAC-SHA1')
          expect(params['Policy']).to eq(policy.serialize)

          expect(token.access_key_id).to eq('sts_id')
          expect(token.access_key_secret).to eq('sts_key')
          expect(token.security_token).to eq('sts_token')
          expect(token.expiration).to eq(expiration)
        end
      end

    end # Client

  end # OSS
end # Aliyun
