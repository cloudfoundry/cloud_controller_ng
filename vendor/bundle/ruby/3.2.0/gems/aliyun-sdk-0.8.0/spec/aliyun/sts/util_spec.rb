# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'yaml'
require 'nokogiri'

module Aliyun
  module STS

    describe Util do

      it "should get correct signature" do
        key = 'helloworld'
        ts = '2015-12-07T07:18:41Z'

        params = {
          'Action' => 'AssumeRole',
          'RoleArn' => 'role-1',
          'RoleSessionName' => 'app-1',
          'DurationSeconds' => '300',
          'Format' => 'XML',
          'Version' => '2015-04-01',
          'AccessKeyId' => 'xxx',
          'SignatureMethod' => 'HMAC-SHA1',
          'SignatureVersion' => '1.0',
          'SignatureNonce' => '3.14159',
          'Timestamp' => ts
        }

        signature = Util.get_signature('POST', params, key)
        expect(signature).to eq("92ta30QopCT4YTbRCaWtS31kyeg=")

        signature = Util.get_signature('GET', params, key)
        expect(signature).to eq("nvMmnOSxGrfK+1zf0oFR5RB2M7k=")
      end

    end # Util
  end # OSS
end # Aliyun
