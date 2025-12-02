#!/usr/bin/env ruby

# uaa create-client decode-token-demo -s decode-token-demo -v \
#   --authorized_grant_types password,refresh_token \
#   --scope "openid"  \
#   --authorities uaa.none

require 'uaa'

url = ENV["UAA_URL"]
client, secret = "decode-token-demo", "decode-token-demo"
username, password = ENV["UAA_USERNAME"], ENV["UAA_PASSWORD"]

def show(title, object)
  puts "#{title}: #{object.inspect}"
  puts
end

uaa_options = {}
uaa_options[:ssl_ca_file] = ENV["UAA_CA_CERT_FILE"] if ENV["UAA_CA_CERT_FILE"]
show "uaa_options", uaa_options

uaa_info = CF::UAA::Info.new(url, uaa_options)
show "UAA server info", uaa_info.server

token_keys = uaa_info.validation_keys_hash
show "Signing keys for access tokens", token_keys

token_issuer = CF::UAA::TokenIssuer.new(url, client, secret, uaa_options)
show "Login prompts", token_issuer.prompts

token = token_issuer.owner_password_grant(username, password, "openid")
show "User '#{username}' password grant", token

auth_header = "bearer #{token.info["access_token"]}"
show "Auth header for resource server API calls", auth_header

userinfo = uaa_info.whoami(auth_header)
show "User info", userinfo

last_exception = nil
token_keys.each_pair do |keyname, token_key|
  begin
    token_coder = CF::UAA::TokenCoder.new(uaa_options.merge(pkey: token_key["value"], verify: true))
    token_info = token_coder.decode(auth_header)
    show "Decoded access token", token_info
    last_exception = nil
  rescue CF::UAA::Decode => e
    last_exception = e
  end
end
raise last_exception if last_exception

