#--
# Cloud Foundry
# Copyright (c) [2009-2014] Pivotal Software, Inc. All Rights Reserved.
#
# This product is licensed to you under the Apache License, Version 2.0 (the "License").
# You may not use this product except in compliance with the License.
#
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the
# subcomponent's license, as noted in the LICENSE file.
#++

require 'spec_helper'
require 'uaa/info'

module CF::UAA

  describe Info do
    let(:options) { {} }
    let(:uaa_info) { Info.new(target, options) }
    let(:target) { 'https://login.cloudfoundry.com' }
    let(:authorization) { nil }

    before do
      uaa_info.set_request_handler do |url, method, body, headers|
        url.should == target_url
        method.should == :get
        headers['content-type'].should be_nil
        headers['accept'].gsub(/\s/, '').should =~ /application\/json;charset=utf-8/i
        headers['authorization'].should == authorization
        [200, response_body, {'content-type' => 'application/json'}]
      end
    end

    describe 'initialize' do
      let(:options) { {skip_ssl_validation: true} }

      it 'sets proxy information' do
        uaa_info.skip_ssl_validation == true
      end
    end

    describe 'getting server info' do
      let(:target_url) { 'https://login.cloudfoundry.com/login' }
      let(:response_body) { '{"commit_id":"12345","prompts":["one","two"]}' }

      it 'gets server info' do
        result = uaa_info.server
        result['prompts'].should_not be_nil
        result['commit_id'].should_not be_nil
      end

      context 'with symbolize_keys keys true' do
        let(:options) { {symbolize_keys: true} }

        it 'gets server info' do
          result = uaa_info.server
          result[:prompts].should_not be_nil
          result[:commit_id].should_not be_nil
        end
      end
    end

    describe 'getting UAA target' do
      let(:target) { 'https://login.cloudfoundry.com' }
      let(:target_url) { 'https://login.cloudfoundry.com/login' }
      let(:response_body) { '{"links":{"uaa":"https://uaa.cloudfoundry.com"},"prompts":["one","two"]}' }

      it 'gets UAA target' do
        result = uaa_info.discover_uaa
        result.should == 'https://uaa.cloudfoundry.com'
      end

      context "when there is no 'links' key present" do
        let(:target) { 'https://uaa.cloudfoundry.com' }
        let(:target_url) { 'https://uaa.cloudfoundry.com/login' }
        let(:response_body) { '{ "prompts" : ["one","two"]} ' }

        it 'returns the target url' do
          result = uaa_info.discover_uaa
          result.should == 'https://uaa.cloudfoundry.com'
        end
      end

      context 'with symbolize_keys keys true' do
        let(:options) { {symbolize_keys: true} }

        it 'gets UAA target' do
          result = uaa_info.discover_uaa
          result.should == 'https://uaa.cloudfoundry.com'
        end
      end
    end

    describe 'whoami' do
      let(:target_url) { 'https://login.cloudfoundry.com/userinfo?schema=openid' }
      let(:response_body) { '{"user_id":"1111-1111-1111-1111","user_name":"user","given_name":"first","family_name":"last","name":"first last","email":"email@example.com"}' }
      let(:authorization) { 'authentication_token' }

      it 'returns the user info' do
        result = uaa_info.whoami(authorization)
        result['email'].should == 'email@example.com'
      end
    end

    describe 'validation_key' do
      let(:target_url) { 'https://login.cloudfoundry.com/token_key' }
      let(:response_body) { '{"alg":"SHA256withRSA","value":"-----BEGIN PUBLIC KEY-----\nabc123\n-----END PUBLIC KEY-----\n"}' }

      it 'returns the key data' do
        result = uaa_info.validation_key(authorization)
        result['alg'].should == 'SHA256withRSA'
      end
    end

    describe 'validation keys' do
      let(:target_url) { 'https://login.cloudfoundry.com/token_keys' }
      let(:response_body) { '{ "keys": [ { "kid": "the_key", "alg": "SHA256withRSA", "value": "-----BEGIN PUBLIC KEY-----\nabc123\n-----END PUBLIC KEY-----\n", "kty": "RSA", "use": "sig", "n": "Ufn7Qc", "e": "EEXZ" }, { "kid": "the_other_key", "alg": "SHA256withRSA", "value": "-----BEGIN PUBLIC KEY-----\ndef456\n-----END PUBLIC KEY-----\n", "kty": "RSA", "use": "sig", "n": "AMcW9/P", "e": "AQAB" } ] }' }

      it 'returns a hash of keys' do
        result = uaa_info.validation_keys_hash(authorization)

        the_key = result['the_key']
        the_key.should_not be_nil

        the_other_key = result['the_other_key']
        the_other_key.should_not be_nil

        the_key['alg'].should == 'SHA256withRSA'
        the_other_key['alg'].should == 'SHA256withRSA'

        the_key['value'].should == "-----BEGIN PUBLIC KEY-----\nabc123\n-----END PUBLIC KEY-----\n"
        the_other_key['value'].should == "-----BEGIN PUBLIC KEY-----\ndef456\n-----END PUBLIC KEY-----\n"
      end
    end
  end
end
