# CloudFoundry UAA Gem
![Build status](https://github.com/cloudfoundry/cf-uaa-lib/actions/workflows/ruby.yml/badge.svg?branch=master)
[![Gem Version](https://badge.fury.io/rb/cf-uaa-lib.png)](http://badge.fury.io/rb/cf-uaa-lib)

Client gem for interacting with the [CloudFoundry UAA server](https://github.com/cloudfoundry/uaa)

For documentation see: https://rubygems.org/gems/cf-uaa-lib

## Install from rubygems

```plain
gem install cf-uaa-lib
```

## Build from source

```plain
bundle install
rake install
```

## Use the gem

Create a UAA client that allows users to authenticate with username/password and allow client application to use `openid` scope to invoke `/userinfo` endpoint for the user.

```plain
uaa create-client decode-token-demo -s decode-token-demo -v \
  --authorized_grant_types password,refresh_token \
  --scope "openid"  \
  --authorities uaa.none
```

Create a user with which to authorize our `decode-token-demo` client application.

```plain
uaa create-user myuser \
  --email myuser@example.com \
  --givenName "My" \
  --familyName "User" \
  --password myuser_secret
```

Create this Ruby script (script is available at `examples/password_grant_and_decode_token.rb`):

```ruby
#!/usr/bin/env ruby

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
```

To run the script, setup the env vars for your UAA and run the ruby script:

```bash
export UAA_URL=https://192.168.50.6:8443
export UAA_CA_CERT_FILE=/path/to/ca.pem
export UAA_USERNAME=myuser
export UAA_PASSWORD=myuser_secret
ruby examples/password_grant_and_decode_token.rb
```

The output will look similar to:

```plain
uaa_options: {:ssl_ca_file=>"/var/folders/wd/xnncwqp96rj0v1y2nms64mq80000gn/T/tmp.R6wpXYdC/ca.pem"}

UAA server info: {"app"=>{"version"=>"4.19.0"}, "links"=>{"uaa"=>"https://192.168.50.6:8443", "passwd"=>"/forgot_password", "login"=>"https://192.168.50.6:8443", "register"=>"/create_account"}, "zone_name"=>"uaa", "entityID"=>"192.168.50.6:8443", "commit_id"=>"7897100", "idpDefinitions"=>{}, "prompts"=>{"username"=>["text", "Email"], "password"=>["password", "Password"]}, "timestamp"=>"2018-06-13T12:02:09-0700"}

Cookie#domain returns dot-less domain name now. Use Cookie#dot_domain if you need "." at the beginning.
Signing keys for access tokens: {"uaa-jwt-key-1"=>{"kty"=>"RSA", "e"=>"AQAB", "use"=>"sig", "kid"=>"uaa-jwt-key-1", "alg"=>"RS256", "value"=>"-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA8UNioYHjhyi1qSHrnBZ9\nKE96/1jLBOX2UTShGBo8jP7eDD6zUh5DNHNPAwD1V8gNI4wvNAm+zL1MrSEDWzn2\nPvCANd+XydoNVZU1zhqxvGhoxHmgAA3JbgSS3oLLNDG/HH8wEnjAxb+G1uh2EVSF\nAe/euQ/fEmY4e7uOG34h9WMX84tD1Sf/xvVoNGAL8bTwotzBLFZ12M3P70hrKDi5\n9wEBbY5bllvvNFyjZTYwMbw97RIOdg3FQkOABu8ENCqbPks5gqSpNV33ekaX4rAd\nwYdEX5iUzDBdMyD8jqUopuqTXqBKg2/ealGitXdbSIEAvcBgZWnn1j2vFp6OEYBB\n7wIDAQAB\n-----END PUBLIC KEY-----", "n"=>"APFDYqGB44cotakh65wWfShPev9YywTl9lE0oRgaPIz-3gw-s1IeQzRzTwMA9VfIDSOMLzQJvsy9TK0hA1s59j7wgDXfl8naDVWVNc4asbxoaMR5oAANyW4Ekt6CyzQxvxx_MBJ4wMW_htbodhFUhQHv3rkP3xJmOHu7jht-IfVjF_OLQ9Un_8b1aDRgC_G08KLcwSxWddjNz-9Iayg4ufcBAW2OW5Zb7zRco2U2MDG8Pe0SDnYNxUJDgAbvBDQqmz5LOYKkqTVd93pGl-KwHcGHRF-YlMwwXTMg_I6lKKbqk16gSoNv3mpRorV3W0iBAL3AYGVp59Y9rxaejhGAQe8"}}

Login prompts: {"username"=>["text", "Email"], "password"=>["password", "Password"]}

User 'myuser' password grant: #<CF::UAA::TokenInfo:0x00007fbad5a12c18 @info={"access_token"=>"eyJhbGciOiJSUzI1NiIsImtpZCI6InVhYS1qd3Qta2V5LTEiLCJ0eXAiOiJKV1QifQ.eyJqdGkiOiJlMTFlZmMwNjI1OGQ0MzA0YTc4ZGIyNzliYjJjMzQ1OCIsInN1YiI6IjM5NzhmZjRkLWQ3MzgtNGI4Yi05OTA4LTdhZTE0N2YzYzNiZSIsInNjb3BlIjpbIm9wZW5pZCJdLCJjbGllbnRfaWQiOiJkZWNvZGUtdG9rZW4tZGVtbyIsImNpZCI6ImRlY29kZS10b2tlbi1kZW1vIiwiYXpwIjoiZGVjb2RlLXRva2VuLWRlbW8iLCJncmFudF90eXBlIjoicGFzc3dvcmQiLCJ1c2VyX2lkIjoiMzk3OGZmNGQtZDczOC00YjhiLTk5MDgtN2FlMTQ3ZjNjM2JlIiwib3JpZ2luIjoidWFhIiwidXNlcl9uYW1lIjoibXl1c2VyIiwiZW1haWwiOiJteXVzZXJAZXhhbXBsZS5jb20iLCJhdXRoX3RpbWUiOjE1MzE2MzAxNDgsInJldl9zaWciOiI5M2E2NzkwNCIsImlhdCI6MTUzMTYzMDE0OCwiZXhwIjoxNTMxNjczMzQ4LCJpc3MiOiJodHRwczovLzE5Mi4xNjguNTAuNjo4NDQzL29hdXRoL3Rva2VuIiwiemlkIjoidWFhIiwiYXVkIjpbIm9wZW5pZCIsImRlY29kZS10b2tlbi1kZW1vIl19.qtbzxCOW5bebTgMLK-71_zxaT7l5PSmxhXcDtCeA64dZZ6-wXXmJivopm5PFEHnHiZwRpVe43jyEsbJGzBdl8GEsYQ9YIy51-4noby7ClziJv-6rSBYZnZuU5A234QRWclATGksOcz8Ft9PTIKGKLScyLhncwas7W0uiNJ87MFBGWY6Ovvl3Ac5-jHCqiRBXD6vUhzpfmy6_OUr53i9zJgtcQQWgDrOHxnFcRABZcDnhnWdcxh-Hbagtt9dQU46QgpqLJiUvAg-7ypZPGrxnr9UQEO2Q9GrolkbrSeUcfUOkgppxaA_0b6RYpgBR1qg-Ns6jGUxFgPs6Jj8pysfVmA", "token_type"=>"bearer", "refresh_token"=>"6701ddb9397840a1bd339e9f4314448f-r", "expires_in"=>43199, "scope"=>"openid", "jti"=>"e11efc06258d4304a78db279bb2c3458"}>

Auth header for resource server API calls: "bearer eyJhbGciOiJSUzI1NiIsImtpZCI6InVhYS1qd3Qta2V5LTEiLCJ0eXAiOiJKV1QifQ.eyJqdGkiOiJlMTFlZmMwNjI1OGQ0MzA0YTc4ZGIyNzliYjJjMzQ1OCIsInN1YiI6IjM5NzhmZjRkLWQ3MzgtNGI4Yi05OTA4LTdhZTE0N2YzYzNiZSIsInNjb3BlIjpbIm9wZW5pZCJdLCJjbGllbnRfaWQiOiJkZWNvZGUtdG9rZW4tZGVtbyIsImNpZCI6ImRlY29kZS10b2tlbi1kZW1vIiwiYXpwIjoiZGVjb2RlLXRva2VuLWRlbW8iLCJncmFudF90eXBlIjoicGFzc3dvcmQiLCJ1c2VyX2lkIjoiMzk3OGZmNGQtZDczOC00YjhiLTk5MDgtN2FlMTQ3ZjNjM2JlIiwib3JpZ2luIjoidWFhIiwidXNlcl9uYW1lIjoibXl1c2VyIiwiZW1haWwiOiJteXVzZXJAZXhhbXBsZS5jb20iLCJhdXRoX3RpbWUiOjE1MzE2MzAxNDgsInJldl9zaWciOiI5M2E2NzkwNCIsImlhdCI6MTUzMTYzMDE0OCwiZXhwIjoxNTMxNjczMzQ4LCJpc3MiOiJodHRwczovLzE5Mi4xNjguNTAuNjo4NDQzL29hdXRoL3Rva2VuIiwiemlkIjoidWFhIiwiYXVkIjpbIm9wZW5pZCIsImRlY29kZS10b2tlbi1kZW1vIl19.qtbzxCOW5bebTgMLK-71_zxaT7l5PSmxhXcDtCeA64dZZ6-wXXmJivopm5PFEHnHiZwRpVe43jyEsbJGzBdl8GEsYQ9YIy51-4noby7ClziJv-6rSBYZnZuU5A234QRWclATGksOcz8Ft9PTIKGKLScyLhncwas7W0uiNJ87MFBGWY6Ovvl3Ac5-jHCqiRBXD6vUhzpfmy6_OUr53i9zJgtcQQWgDrOHxnFcRABZcDnhnWdcxh-Hbagtt9dQU46QgpqLJiUvAg-7ypZPGrxnr9UQEO2Q9GrolkbrSeUcfUOkgppxaA_0b6RYpgBR1qg-Ns6jGUxFgPs6Jj8pysfVmA"

User info: {"user_id"=>"3978ff4d-d738-4b8b-9908-7ae147f3c3be", "user_name"=>"myuser", "name"=>"My User", "given_name"=>"My", "family_name"=>"User", "email"=>"myuser@example.com", "email_verified"=>true, "previous_logon_time"=>nil, "sub"=>"3978ff4d-d738-4b8b-9908-7ae147f3c3be"}

Decoded access token: {"jti"=>"e11efc06258d4304a78db279bb2c3458", "sub"=>"3978ff4d-d738-4b8b-9908-7ae147f3c3be", "scope"=>["openid"], "client_id"=>"decode-token-demo", "cid"=>"decode-token-demo", "azp"=>"decode-token-demo", "grant_type"=>"password", "user_id"=>"3978ff4d-d738-4b8b-9908-7ae147f3c3be", "origin"=>"uaa", "user_name"=>"myuser", "email"=>"myuser@example.com", "auth_time"=>1531630148, "rev_sig"=>"93a67904", "iat"=>1531630148, "exp"=>1531673348, "iss"=>"https://192.168.50.6:8443/oauth/token", "zid"=>"uaa", "aud"=>["openid", "decode-token-demo"]}
>>>>>>> 21ae635... new example script - password grant + decode using token keys
```

## Tests

Run the tests with rake:

```plain
bundle exec rake test
```

Run the tests and see a fancy coverage report:

```plain
bundle exec rake cov
```

