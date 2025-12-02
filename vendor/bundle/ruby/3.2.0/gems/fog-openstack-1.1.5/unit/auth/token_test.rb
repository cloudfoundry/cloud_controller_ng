require 'test_helper'
require 'auth_helper'

describe Fog::OpenStack::Auth::Token do
  describe 'V3' do
    describe '#new' do
      it 'fails when missing credentials' do
        stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
          to_return(
            :status  => 200,
            :body    => "{\"token\":{\"catalog\":[]}}",
            :headers => {'x-subject-token'=>'token_data'}
          )

        proc do
          Fog::OpenStack::Auth::Token.build({}, {})
        end.must_raise Fog::OpenStack::Auth::Token::URLError
      end

      describe 'using the password method' do
        describe 'with a project scope' do
          it 'authenticates using a project id' do
            auth = {
              :openstack_auth_url   => 'http://localhost/identity',
              :openstack_userid     => 'user_id',
              :openstack_api_key    => 'secret',
              :openstack_project_id => 'project_id'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":\
{\"id\":\"user_id\",\"password\":\"secret\"}}},\"scope\":{\"project\":{\"id\":\"project_id\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data_v3'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data_v3'
          end

          it 'authenticates using a project name and a project domain id' do
            auth = {
              :openstack_auth_url          => 'http://localhost/identity',
              :openstack_userid            => 'user_id',
              :openstack_api_key           => 'secret',
              :openstack_project_name      => 'project',
              :openstack_project_domain_id => 'project_domain_id'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"id\":\
\"user_id\",\"password\":\"secret\"}}},\"scope\":{\"project\":{\"name\":\"project\",\"domain\":{\"id\":\
\"project_domain_id\"}}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end

          it 'authenticates using a project name and a project domain name' do
            auth = {
              :openstack_auth_url            => 'http://localhost/identity',
              :openstack_username            => 'user',
              :openstack_user_domain_name    => 'user_domain',
              :openstack_api_key             => 'secret',
              :openstack_project_name        => 'project',
              :openstack_project_domain_name => 'project_domain'
            }

            stub_request(:post, "http://localhost/identity/v3/auth/tokens").
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"name\":\
\"user\",\"domain\":{\"name\":\"user_domain\"},\"password\":\"secret\"}}},\"scope\":{\"project\":{\"name\":\"project\"\
,\"domain\":{\"name\":\"project_domain\"}}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end
        end

        describe 'with a domain scope' do
          it 'authenticates using a domain id' do
            auth = {
              :openstack_auth_url  => 'http://localhost/identity',
              :openstack_userid    => 'user_id',
              :openstack_api_key   => 'secret',
              :openstack_domain_id => 'domain_id'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"id\":\
\"user_id\",\"password\":\"secret\"}}},\"scope\":{\"domain\":{\"id\":\"domain_id\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end

          it 'authenticates using a domain name' do
            auth = {
              :openstack_auth_url    => 'http://localhost/identity',
              :openstack_userid      => 'user_id',
              :openstack_api_key     => 'secret',
              :openstack_domain_name => 'domain'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"id\":\
\"user_id\",\"password\":\"secret\"}}},\"scope\":{\"domain\":{\"name\":\"domain\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end
        end

        describe 'unscoped' do
          it 'authenticates' do
            auth = {
              :openstack_auth_url => 'http://localhost/identity',
              :openstack_userid   => 'user_id',
              :openstack_api_key  => 'secret',
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"id\":\
\"user_id\",\"password\":\"secret\"}}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end
        end
      end

      describe 'using the token method' do
        describe 'unscoped' do
          it 'authenticates using a project id' do
            auth = {
              :openstack_auth_url   => 'http://localhost/identity',
              :openstack_auth_token => 'token',
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"token\"],\"token\":{\"id\":\"token\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end
        end

        describe 'with a project scope' do
          it 'authenticates using a project id' do
            auth = {
              :openstack_auth_url   => 'http://localhost/identity',
              :openstack_auth_token => 'token',
              :openstack_project_id => 'project_id'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"token\"],\"token\":{\"id\":\"token\"}},\
\"scope\":{\"project\":{\"id\":\"project_id\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end

          it 'authenticates using a project name and a project domain id' do
            auth = {
              :openstack_auth_url          => 'http://localhost/identity',
              :openstack_auth_token        => 'token',
              :openstack_project_name      => 'project',
              :openstack_project_domain_id => 'domain_id'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"token\"],\"token\":{\"id\":\"token\"}},\
\"scope\":{\"project\":{\"name\":\"project\",\"domain\":{\"id\":\"domain_id\"}}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end
        end

        describe 'with a domain scope' do
          it 'authenticates using a domain id' do
            auth = {
              :openstack_auth_url   => 'http://localhost/identity',
              :openstack_auth_token => 'token',
              :openstack_domain_id  => 'domain_id'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"token\"],\"token\":{\"id\":\"token\"}},\
\"scope\":{\"domain\":{\"id\":\"domain_id\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end

          it 'authenticates using a domain name' do
            auth = {
              :openstack_auth_url    => 'http://localhost/identity',
              :openstack_auth_token  => 'token',
              :openstack_domain_name => 'domain'
            }

            stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
              with(:body => "{\"auth\":{\"identity\":{\"methods\":[\"token\"],\"token\":{\"id\":\"token\"}},\
\"scope\":{\"domain\":{\"name\":\"domain\"}}}}").
              to_return(
                :status  => 200,
                :body    => JSON.dump(auth_response_v3('identity', 'keystone')),
                :headers => {'x-subject-token'=>'token_data'}
              )

            token = Fog::OpenStack::Auth::Token.build(auth, {})
            token.get.must_equal 'token_data'
          end
        end
      end
    end

    describe 'when authenticated' do
      let(:authv3_creds) do
        {
          :openstack_auth_url          => 'http://localhost/identity',
          :openstack_username          => 'admin',
          :openstack_api_key           => 'secret',
          :openstack_project_name      => 'admin',
          :openstack_project_domain_id => 'default'
        }
      end

      describe '#get' do
        it 'when token has not expired' do
          stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
            to_return(
              :status  => 200,
              :body    => "{\"token\":{\"catalog\":[\"catalog_data\"]}}",
              :headers => {'x-subject-token'=>'token_data'}
            )

          token = Fog::OpenStack::Auth::Token.build(authv3_creds, {})
          token.stub :expired?, false do
            token.get.must_equal 'token_data'
          end
        end

        it 'when token has expired' do
          stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
            to_return(
              :status  => 200,
              :body    => "{\"token\":{\"catalog\":[\"catalog_data\"]}}",
              :headers => {'x-subject-token'=>'token_data'}
            )

          token = Fog::OpenStack::Auth::Token.build(authv3_creds, {})
          token.stub :expired?, true do
            token.get.must_equal 'token_data'
          end
        end
      end

      it '#catalog' do
        stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
          to_return(
            :status  => 200,
            :body    => "{\"token\":{\"catalog\":[\"catalog_data\"]}}",
            :headers => {'x-subject-token'=>'token_data'}
          )

        token = Fog::OpenStack::Auth::Token.build(authv3_creds, {})
        token.catalog.payload.must_equal ['catalog_data']
      end

      it '#get_endpoint_url' do
        stub_request(:post, 'http://localhost/identity/v3/auth/tokens').
          to_return(
            :status  => 200,
            :body    => JSON.dump(auth_response_v3("identity", "keystone")),
            :headers => {'x-subject-token'=>'token_data'}
          )

        token = Fog::OpenStack::Auth::Token.build(authv3_creds, {})
        token.catalog.get_endpoint_url(%w[identity], 'public', 'regionOne').must_equal 'http://localhost'
      end
    end
  end

  describe 'V2' do
    describe '#new' do
      it 'fails when missing credentials' do
        stub_request(:post, 'http://localhost/identity/v2.0/tokens').
          to_return(:status => 200, :body => "{\"access\":{\"token\":{\"id\":\"token_data\"}}}", :headers => {})

        proc do
          Fog::OpenStack::Auth::Token.build({}, {})
        end.must_raise Fog::OpenStack::Auth::Token::URLError
      end

      describe 'using the password method' do
        it 'authenticates using the tenant name' do
          auth = {
            :openstack_auth_url => 'http://localhost/identity',
            :openstack_username => 'user',
            :openstack_api_key  => 'secret',
            :openstack_tenant   => 'tenant',
          }

          stub_request(:post, 'http://localhost/identity/v2.0/tokens').
            with(:body => "{\"auth\":{\"passwordCredentials\":{\"username\":\"user\",\"password\":\"secret\"},\
\"tenantName\":\"tenant\"}}").
            to_return(:status => 200, :body => JSON.dump(auth_response_v2('identity', 'keystone')), :headers => {})

          token = Fog::OpenStack::Auth::Token.build(auth, {})
          token.get.must_equal '4ae647d3a5294690a3c29bc658e17e26'
        end

        it 'authenticates using the tenant id' do
          auth = {
            :openstack_auth_url  => 'http://localhost/identity',
            :openstack_username  => 'user',
            :openstack_api_key   => 'secret',
            :openstack_tenant_id => 'tenant_id',
          }

          stub_request(:post, 'http://localhost/identity/v2.0/tokens').
            with(:body => "{\"auth\":{\"passwordCredentials\":{\"username\":\"user\",\"password\":\"secret\"},\
\"tenantId\":\"tenant_id\"}}").
            to_return(:status => 200, :body => JSON.dump(auth_response_v2('identity', 'keystone')), :headers => {})

          token = Fog::OpenStack::Auth::Token.build(auth, {})
          token.get.must_equal '4ae647d3a5294690a3c29bc658e17e26'
        end
      end

      describe 'using the token method' do
        it 'authenticates using the tenant name' do
          auth = {
            :openstack_auth_url   => 'http://localhost/identity',
            :openstack_auth_token => 'token_id',
            :openstack_tenant     => 'tenant',
          }

          stub_request(:post, 'http://localhost/identity/v2.0/tokens').
            with(:body => "{\"auth\":{\"token\":{\"id\":\"token_id\"},\"tenantName\":\"tenant\"}}").
            to_return(:status => 200, :body => JSON.dump(auth_response_v2('identity', 'keystone')), :headers => {})

          token = Fog::OpenStack::Auth::Token.build(auth, {})
          token.get.must_equal '4ae647d3a5294690a3c29bc658e17e26'
        end

        it 'authenticates using the tenant id' do
          auth = {
            :openstack_auth_url   => 'http://localhost/identity',
            :openstack_auth_token => 'token_id',
            :openstack_tenant_id  => 'tenant_id',
          }

          stub_request(:post, 'http://localhost/identity/v2.0/tokens').
            with(:body => "{\"auth\":{\"token\":{\"id\":\"token_id\"},\"tenantId\":\"tenant_id\"}}").
            to_return(:status => 200, :body => JSON.dump(auth_response_v2('identity', 'keystone')), :headers => {})

          Fog::OpenStack::Auth::Token.build(auth, {})
        end
      end
    end

    describe 'when authenticated' do
      let(:authv2_creds) do
        {
          :openstack_auth_url => 'http://localhost/identity',
          :openstack_username => 'admin',
          :openstack_api_key  => 'secret',
          :openstack_tenant   => 'admin'
        }
      end

      describe '#get' do
        it 'when token has not expired' do
          stub_request(:post, 'http://localhost/identity/v2.0/tokens').
            to_return(
              :status  => 200,
              :body    => "{\"access\":{\"token\":{\"id\":\"token_not_expired\"},\"serviceCatalog\":\
[\"catalog_data\"]}}",
              :headers => {}
            )

          token = Fog::OpenStack::Auth::Token.build(authv2_creds, {})
          token.stub :expired?, false do
            token.get.must_equal 'token_not_expired'
          end
        end

        it 'when token has expired' do
          stub_request(:post, 'http://localhost/identity/v2.0/tokens').
            to_return(
              :status  => 200,
              :body    => "{\"access\":{\"token\":{\"id\":\"token_expired\"},\"serviceCatalog\":[\"catalog_data\"]}}",
              :headers => {}
            )

          token = Fog::OpenStack::Auth::Token.build(authv2_creds, {})
          token.stub :expired?, true do
            token.get.must_equal 'token_expired'
          end
        end
      end

      it '#catalog' do
        stub_request(:post, 'http://localhost/identity/v2.0/tokens').
          to_return(
            :status  => 200,
            :body    => "{\"access\":{\"token\":{\"id\":\"token_data\"},\"serviceCatalog\":[\"catalog_data\"]}}",
            :headers => {}
          )

        token = Fog::OpenStack::Auth::Token.build(authv2_creds, {})
        token.catalog.payload.must_equal ['catalog_data']
      end

      it '#get_endpoint_url' do
        stub_request(:post, 'http://localhost/identity/v2.0/tokens').
          to_return(
            :status  => 200,
            :body    => JSON.dump(auth_response_v2('identity', 'keystone')),
            :headers => {'x-subject-token'=>'token_data'}
          )

        token = Fog::OpenStack::Auth::Token.build(authv2_creds, {})
        token.catalog.get_endpoint_url(%w[identity], 'public', 'regionOne').must_equal 'http://localhost'
      end
    end
  end
end
