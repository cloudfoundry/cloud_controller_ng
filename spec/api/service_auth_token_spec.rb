# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::ServiceAuthToken do
  let(:service_auth_token)   { VCAP::CloudController::Models::ServiceAuthToken.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/service_auth_tokens',
    :model                => VCAP::CloudController::Models::ServiceAuthToken,
    :basic_attributes     => [:label, :provider],
    :required_attributes  => [:label, :provider, :token],
    :unique_attributes    => [:label, :provider],
    :extra_attributes     => :token,
    :sensitive_attributes => :token
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::ServiceAuthToken,
    [
      ['/v2/service_auth_tokens', :post, 201, 403, 401, { :label => Sham.label, :provider => Sham.provider, :token => Sham.token }],
      ['/v2/service_auth_tokens', :get, 200, 403, 401],
      ['/v2/service_auth_tokens/#{service_auth_token.id}', :put, 201, 403, 401, { :label => '#{service_auth_token.label}_renamed' }],
      ['/v2/service_auth_tokens/#{service_auth_token.id}', :delete, 204, 403, 401],
    ]

end
