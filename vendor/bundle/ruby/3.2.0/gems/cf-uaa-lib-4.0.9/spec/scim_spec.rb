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
require 'uaa/scim'
require 'uri'
require 'cgi'

module CF::UAA

describe Scim do
  let(:options) { {} }

  before do
    #Util.default_logger(:trace)
    @authheader, @target = 'bEareR xyz', 'https://test.target'
    @scim = Scim.new(@target, @authheader, options)
  end

  subject { @scim }

  def check_headers(headers, content, accept, zone)
    headers['content-type'].should =~ /application\/json/ if content == :json
    headers['content-type'].should be_nil unless content
    headers['accept'].should =~ /application\/json/ if accept == :json
    headers['accept'].should be_nil unless accept
    headers['authorization'].should =~ /^(?i:bearer)\s+xyz$/
    headers['X-Identity-Zone-Subdomain'].should eq zone
  end

  describe 'initialize' do
    let(:options) { {http_proxy: 'http-proxy.com', https_proxy: 'https-proxy.com', skip_ssl_validation: true} }

    it 'sets skip_ssl_validation' do
      subject.skip_ssl_validation == true
    end
  end

  it 'adds an object' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users"
      method.should == :post
      check_headers(headers, :json, :json, nil)
      [200, '{"ID":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.add(:user, hair: 'brown', shoe_size: 'large',
        eye_color: ['blue', 'green'], name: 'fred')
    result['id'].should == 'id12345'
  end

  it 'gets client meta' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/oauth/clients/id12345/meta"
      method.should == :get
      check_headers(headers, nil, :json, nil)
      [200, '{"id":"id12345", "created_by": "Marissa"}', {'content-type' => 'application/json'}]
    end
    result = subject.get_client_meta('id12345')
    result['id'].should == 'id12345'
    result['created_by'].should == 'Marissa'
  end

  it 'replaces an object' do
    obj = {hair: 'black', shoe_size: 'medium', eye_color: ['hazel', 'brown'],
          name: 'fredrick', meta: {version: 'v567'}, id: 'id12345'}
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users/id12345"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      headers['if-match'].should == 'v567'
      [200, '{"ID":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.put(:user, obj)
    result['id'].should == 'id12345'
  end

  it 'modifies an object' do
    obj = {hair: 'black', shoe_size: 'medium', eye_color: ['hazel', 'brown'],
          name: 'fredrick', meta: {version: 'v567'}, id: 'id12345'}
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users/id12345"
      method.should == :patch
      check_headers(headers, :json, :json, nil)
      headers['if-match'].should == 'v567'
      [200, '{"ID":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.patch(:user, obj)
    result['id'].should == 'id12345'
  end

  it 'gets an object' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users/id12345"
      method.should == :get
      check_headers(headers, nil, :json, nil)
      [200, '{"id":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.get(:user, 'id12345')
    result['id'].should == 'id12345'
  end

  it 'pages through all objects' do
    subject.set_request_handler do |url, method, body, headers|
      url.should =~ %r{^#{@target}/Users\?}
      url.should =~ %r{[\?&]attributes=id(&|$)}
      url.should =~ %r{[\?&]includeInactive=true(&|$)}
      url.should =~ %r{[\?&]startIndex=[12](&|$)}
      method.should == :get
      check_headers(headers, nil, :json, nil)
      reply = url =~ /startIndex=1/ ?
        '{"TotalResults":2,"ItemsPerPage":1,"StartIndex":1,"RESOURCES":[{"id":"id12345"}]}' :
        '{"TotalResults":2,"ItemsPerPage":1,"StartIndex":2,"RESOURCES":[{"id":"id67890"}]}'
      [200, reply, {'content-type' => 'application/json'}]
    end
    result = subject.all_pages(:user, attributes: 'id', includeInactive: true)
    [result[0]['id'], result[1]['id']].to_set.should == ['id12345', 'id67890'].to_set
  end

  it "changes a user's password" do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users/id12345/password"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      body.should include('"password":"newpwd"', '"oldPassword":"oldpwd"')
      [200, '{"id":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.change_password('id12345', 'newpwd', 'oldpwd')
    result['id'].should == 'id12345'
  end

  it "tries to change the user's password to be the same as the old one" do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users/id12345/password"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      [400, '{"error":"invalid_password","message":"Your new password cannot be the same as the old password."}', {'content-type' => 'application/json'}]
    end
    expect {subject.change_password('id12345', 'oldpwd', 'oldpwd')}.to raise_error(error=TargetError)
  end

  it "changes a client's secret" do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/oauth/clients/id12345/secret"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      body.should include('"secret":"newpwd"', '"oldSecret":"oldpwd"')
      [200, '{"id":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.change_secret('id12345', 'newpwd', 'oldpwd')
    result['id'].should == 'id12345'
  end

  it "add a client's jwt trust using jwks_uri" do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/oauth/clients/id12345/clientjwt"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      body.should include('"jwks_uri":"http://localhost:8080/uaa/token_keys"')
      [200, '{"id":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.change_clientjwt('id12345', 'http://localhost:8080/uaa/token_keys')
    result['id'].should == 'id12345'
  end

  it "add a client's jwt trust using jwks" do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/oauth/clients/id12345/clientjwt"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      body.should include('"jwks":"keys"')
      [200, '{"id":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.change_clientjwt('id12345', nil, 'keys')
    result['id'].should == 'id12345'
  end

  it "add federated client's jwt trust using issuer, subject and audience" do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/oauth/clients/id12345/clientjwt"
      method.should == :put
      check_headers(headers, :json, :json, nil)
      body.should include('"iss":"issuer"', '"sub":"subject"', '"aud":"audience"')
      [200, '{"id":"id12345"}', {'content-type' => 'application/json'}]
    end
    result = subject.change_clientjwt('id12345', jwks_uri=nil, jwks=nil, kid=nil, changemod='ADD', iss='issuer', sub='subject', aud='audience')
    result['id'].should == 'id12345'
  end

  it 'unlocks a user' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Users/id12345/status"
      method.should == :patch
      check_headers(headers, :json, :json, nil)
      body.should include('"locked":false')
      [200, '{"locked":false}', {'content-type' => 'application/json'}]
    end
    result = subject.unlock_user('id12345')
    result['locked'].should == false
  end

  it 'adds a mapping from uaa groups to external group' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Groups/External"
      method.should == :post
      check_headers(headers, :json, :json, nil)
      body.should include('"displayName":"uaa-scope-name"', '"externalGroup":"external-group-name"', '"schemas":["urn:scim:schemas:core:1.0"]', '"origin":"test-origin"')
      [201, '{"displayName":"uaa-scope-name", "externalGroup": "external-group-name"}', {'content-type' => 'application/json'}]
    end
    result = subject.map_group('uaa-scope-name', false, 'external-group-name', 'test-origin')
    result['displayname'].should == 'uaa-scope-name'
    result['externalgroup'].should == 'external-group-name'
  end

  it 'defaults to ldap origin when mapping a uaa group from an external group' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Groups/External"
      method.should == :post
      check_headers(headers, :json, :json, nil)
      body.should include('"displayName":"uaa-scope-name"', '"externalGroup":"external-group-name"', '"schemas":["urn:scim:schemas:core:1.0"]', '"origin":"ldap"')
      [201, '{"displayName":"uaa-scope-name", "externalGroup": "external-group-name"}', {'content-type' => 'application/json'}]
    end
    result = subject.map_group('uaa-scope-name', false, 'external-group-name')
    result['displayname'].should == 'uaa-scope-name'
    result['externalgroup'].should == 'external-group-name'
  end

  it 'unmaps a uaa group from an external group' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Groups/External/groupId/uaa-group-id/externalGroup/external%20group%20name/origin/test-origin"
      method.should == :delete
      check_headers(headers, nil, nil, nil)

      [200, '{"displayName":"uaa-scope-name", "groupId": "uaa-group-id", "externalGroup": "external-group-name"}', {'content-type' => 'application/json'}]
    end
    subject.unmap_group('uaa-group-id', 'external group name', 'test-origin')
  end

  it 'defaults to ldap origin when unmapping a uaa group from an external group' do
    subject.set_request_handler do |url, method, body, headers|
      url.should == "#{@target}/Groups/External/groupId/uaa-group-id/externalGroup/external%20group%20name/origin/ldap"
      method.should == :delete
      check_headers(headers, nil, nil, nil)

      [200, '{"displayName":"uaa-scope-name", "groupId": "uaa-group-id", "externalGroup": "external-group-name"}', {'content-type' => 'application/json'}]
    end
    subject.unmap_group('uaa-group-id', 'external group name')
  end

  describe 'users in a zone' do
    let(:options) { {http_proxy: 'http-proxy.com', https_proxy: 'https-proxy.com', skip_ssl_validation: true, zone: 'derpzone'} }

    it 'sends zone header' do
        subject.set_request_handler do |url, method, body, headers|
          url.should == "#{@target}/Users"
          method.should == :post
          check_headers(headers, :json, :json, 'derpzone')
          [200, '{"ID":"id12345"}', {'content-type' => 'application/json'}]
        end
        result = subject.add(:user, hair: 'brown', shoe_size: 'large',
                             eye_color: ['blue', 'green'], name: 'fred')
        result['id'].should == 'id12345'
      end
  end

  describe '#list_group_mappings' do
    it 'lists all the external group mappings with default pagination' do
      subject.set_request_handler do |url, method, body, headers|
        url.should start_with("#{@target}/Groups/External/list")
        method.should == :get
        check_headers(headers, nil, :json, nil)

        [
            200,
            '{"resources": [{"groupId": "group-id", "displayName": "group-name", "externalGroup": "external-group-name"}], "totalResults": 1 }',
            {'content-type' => 'application/json'}
        ]
      end

      result = subject.list_group_mappings
      result['resources'].length.should == 1
      result['totalresults'].should == 1
    end

    it 'lists a page of external group mappings starting from an index' do
      subject.set_request_handler do |url, method, body, headers|
        url.should start_with("#{@target}/Groups/External/list")
        method.should == :get
        check_headers(headers, nil, :json, nil)

        query_params = CGI::parse(URI.parse(url).query)
        start_index = query_params['startIndex'].first
        count = query_params['count'].first

        start_index.should == '3'
        count.should == '10'

        [
            200,
            '{"resources": [{"groupId": "group-id", "displayName": "group-name", "externalGroup": "external-group-name"}], "totalResults": 1 }',
            {'content-type' => 'application/json'}
        ]
      end

      subject.list_group_mappings(3, 10)
    end


  end
end

end
