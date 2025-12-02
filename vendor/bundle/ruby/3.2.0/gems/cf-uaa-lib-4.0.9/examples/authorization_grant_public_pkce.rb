#!/usr/bin/env ruby

# Start a develop UAA with default profile or add client with allowpublic=true
# uaac client add login -s loginsecret \
#   --authorized_grant_types authorization_code,refresh_token \
#   --scope "openid"  \
#   --authorities uaa.none \
#   --allowpublic true \
#   --redirect_uri=http://localhost:7000/callback

require 'uaa'
require 'cgi'

url = ENV["UAA_URL"] || 'http://localhost:8080/uaa'
client = "login"
secret = nil

def show(title, object)
  puts "#{title}: #{object.inspect}"
  puts
end

uaa_options = { skip_ssl_validation: true, use_pkce:true, client_auth_method: 'none'}
uaa_options[:ssl_ca_file] = ENV["UAA_CA_CERT_FILE"] if ENV["UAA_CA_CERT_FILE"]
show "uaa_options", uaa_options

uaa_info = CF::UAA::Info.new(url, uaa_options)
show "UAA server info", uaa_info.server

token_issuer = CF::UAA::TokenIssuer.new(url, client, secret, uaa_options)
auth_uri = token_issuer.authcode_uri("http://localhost:7000/callback", nil)
show "UAA authorization URL", auth_uri

puts "Enter Callback URL: "
callback_url = gets
show "Perform Token Request with: ", callback_url

token = token_issuer.authcode_grant(auth_uri, URI.parse(callback_url).query.to_s)
show "User authorization grant", token

token_info = CF::UAA::TokenCoder.decode(token.info["access_token"], nil, nil, false) #token signature not verified
show "Decoded access token", token_info
