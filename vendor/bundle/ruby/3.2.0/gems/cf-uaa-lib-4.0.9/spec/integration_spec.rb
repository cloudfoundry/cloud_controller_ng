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
require 'uaa'
require 'pp'

# ENV['UAA_CLIENT_ID'] = 'admin'
# ENV['UAA_CLIENT_SECRET'] = 'admin_secret'
# ENV['UAA_CLIENT_TARGET'] = 'https://login.identity.cf-app.com'
# ENV['UAA_CLIENT_TARGET'] = 'http://localhost:8080/uaa'

#Set this variable if you want to test skip_ssl_validation option.
#Make sure that  UAA_CLIENT_TARGET points to https endpoint with self-signed certificate.
#It will run  all the tests with ssl validation set to false
# ENV['SKIP_SSL_VALIDATION'] = 'yes'

#Set this variable to test ssl_ca_file option.
#Make sure that  UAA_CLIENT_TARGET points to https endpoint with self-signed certificate.
# ENV['SSL_CA_FILE'] = '~/workspace/identity-cf.cert'

#Set this variable to test cert_store option.
#Make sure that  UAA_CLIENT_TARGET points to https endpoint with self-signed certificate.
# ENV['CERT_STORE'] = '~/workspace/identity-cf.cert'

module CF::UAA

  def self.admin_scim(options)
    admin_client = ENV['UAA_CLIENT_ID'] || 'admin'
    admin_secret = ENV['UAA_CLIENT_SECRET'] || 'adminsecret'
    target = ENV['UAA_CLIENT_TARGET']

    admin_token_issuer = TokenIssuer.new(target, admin_client, admin_secret, options)
    Scim.new(target, admin_token_issuer.client_credentials_grant.auth_header, options.merge(symbolize_keys: true))
  end

  describe 'when UAA does not respond' do
    let(:http_timeout) { 0.01 }
    let(:default_http_client_timeout) { 60 }
    let(:scim) { Scim.new(@target, "", {http_timeout: http_timeout}) }
    let(:token_issuer) { TokenIssuer.new(@target, "", "", {http_timeout: http_timeout}) }
    let(:blackhole_ip) { '10.255.255.1'}

    before do
      @target = "http://#{blackhole_ip}"
    end

    it 'times out the connection at the configured time for the scim' do
      expect {
        Timeout.timeout(default_http_client_timeout - 1) do
          scim.get(:user, "admin")
        end
      }.to raise_error HTTPException
    end

    it 'times out the connection at the configured time for the token issuer' do
      expect {
        Timeout.timeout(default_http_client_timeout - 1) do
          token_issuer.client_credentials_grant
        end
      }.to raise_error HTTPException
    end
  end

  if ENV['UAA_CLIENT_TARGET']
    describe 'UAA Integration:' do

      let(:options)  { @options }
      let(:token_issuer) { TokenIssuer.new(@target, @test_client, @test_secret, options) }
      let(:scim) { Scim.new(@target, token_issuer.client_credentials_grant.auth_header, options.merge(symbolize_keys: true)) }

      before :all do
        @options = {}
        if ENV['SKIP_SSL_VALIDATION']
          @options = {skip_ssl_validation: true}
        end
        @target = ENV['UAA_CLIENT_TARGET']
        @test_client = "test_client_#{Time.now.to_i}"
        @test_secret = '+=tEsTsEcRet~!@'
        gids = ['clients.read', 'scim.read', 'scim.write', 'uaa.resource', 'password.write']
        test_client = CF::UAA::admin_scim(@options).add(:client, client_id: @test_client, client_secret: @test_secret,
                                     authorities: gids, authorized_grant_types: ['client_credentials', 'password'],
                                     scope: ['openid', 'password.write'])
        expect(test_client[:client_id]).to eq(@test_client)
      end

      after :all do
        admin_scim = CF::UAA::admin_scim(@options)
        admin_scim.delete(:client, @test_client)
        expect { admin_scim.id(:client, @test_client) }.to raise_exception(NotFound)
      end

      if ENV['SKIP_SSL_VALIDATION']
        context 'when ssl certificate is self-signed' do
          let(:options)  { {skip_ssl_validation: false} }

          it 'fails if skip_ssl_validation is false' do
            expect{ scim }.to raise_exception(CF::UAA::SSLException)
          end
        end
      end

      if ENV['SSL_CA_FILE']
        context 'when you do not skip SSL validation' do
          context 'when you provide cert' do
            let(:options)  { {ssl_ca_file: ENV['SSL_CA_FILE']} }

            it 'works' do
              expect(token_issuer.prompts).to_not be_nil
            end
          end

          context 'if you do not provide cert file' do
            let(:options)  { {} }

            it 'fails' do
              expect{ scim }.to raise_exception(CF::UAA::SSLException)
            end
          end
        end
      end

      if ENV['CERT_STORE']
        context 'when you do not skip SSL validation' do
          context 'when you provide cert store' do
            let(:cert_store) do
              cert_store = OpenSSL::X509::Store.new
              cert_store.add_file File.expand_path(ENV['CERT_STORE'])
              cert_store
            end

            let(:options)  { {ssl_cert_store: cert_store} }
            it 'works' do
              expect(token_issuer.prompts).to_not be_nil
            end
          end

          context 'when you do not provide cert store' do
            let(:options)  { {} }

            it 'fails' do
              expect{ scim }.to raise_exception(CF::UAA::SSLException)
            end
          end
        end
      end

      it 'should report the uaa client version' do
        expect(VERSION).to match(/\d+.\d+.\d+/)
      end

      it 'makes sure the server is there by getting the prompts for an implicit grant' do
        expect(token_issuer.prompts).to_not be_nil
      end

      it 'gets a token with client credentials' do
        tkn = token_issuer.client_credentials_grant
        expect(tkn.auth_header).to match(/^bearer\s/i)
        info = TokenCoder.decode(tkn.info['access_token'], verify: false, symbolize_keys: true)
        expect(info[:exp]).to be
        expect(info[:jti]).to be
      end

      it 'complains about an attempt to delete a non-existent user' do
        expect { scim.delete(:user, 'non-existent-user') }.to raise_exception(NotFound)
      end

      context 'as a client' do
        before :each do
          @username = "sam_#{Time.now.to_i}"
          @user_pwd = "sam's P@55w0rd~!`@\#\$%^&*()_/{}[]\\|:\";',.<>?/"
          usr = scim.add(:user, username: @username, password: @user_pwd,
                         emails: [{value: 'sam@example.com'}],
                         name: {givenname: 'none', familyname: 'none'})
          @user_id = usr[:id]
        end

        it 'deletes the user' do
          scim.delete(:user, @user_id)
          expect { scim.id(:user, @username) }.to raise_exception(NotFound)
          expect { scim.get(:user, @user_id) }.to raise_exception(NotFound)
        end

        context 'when user exists' do
          after :each do
            scim.delete(:user, @user_id)
            expect { scim.id(:user, @username) }.to raise_exception(NotFound)
            expect { scim.get(:user, @user_id) }.to raise_exception(NotFound)
          end

          it 'creates a user' do
            expect(@user_id).to be
          end

          it 'finds the user by name' do
            expect(scim.id(:user, @username)).to eq(@user_id)
          end

          it 'gets the user by id' do
            user_info = scim.get(:user, @user_id)
            expect(user_info[:id]).to eq(@user_id)
            expect(user_info[:username]).to eq(@username)
          end

          it 'lists all users' do
            expect(scim.query(:user)).to be
          end

          it "changes the user's password by name" do
            expect(scim.change_password(scim.id(:user, @username), 'newpassword')[:status]).to eq('ok')
          end

          it 'should get a uri to be sent to the user agent to initiate autologin' do
            redir_uri = 'http://call.back/uri_path'
            uri_parts = token_issuer.autologin_uri(redir_uri, username: @username,
                                                   password: @user_pwd ).split('?')
            expect(uri_parts[0]).to eq("#{ENV['UAA_CLIENT_TARGET']}/oauth/authorize")
            params = Util.decode_form(uri_parts[1], :sym)
            expect(params[:response_type]).to eq('code')
            expect(params[:client_id]).to eq(@test_client)
            expect(params[:scope]).to be_nil
            expect(params[:redirect_uri]).to eq(redir_uri)
            expect(params[:state]).to be
            expect(params[:code]).to be
          end
        end
      end
    end
  end
end
