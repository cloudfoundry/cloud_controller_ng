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
require 'uaa/token_coder'

module CF::UAA

describe TokenCoder do

  subject { TokenCoder.new(audience_ids: "test_resource",
      skey: "test_secret", pkey: OpenSSL::PKey::RSA.generate(512) ) }

  before :each do
    @tkn_body = {'foo' => "bar"}
    @tkn_secret = "test_secret"
  end

  it "raises error if the given auth header is bad" do
    expect { subject.decode(nil) }.to raise_exception(InvalidTokenFormat)
    expect { subject.decode("one two three") }.to raise_exception(InvalidTokenFormat)
  end

  it "encodes/decodes a token using a symmetrical key" do
    tkn = subject.encode(@tkn_body, 'HS512')
    result = subject.decode("bEaReR #{tkn}")
    result.should_not be_nil
    result["foo"].should == "bar"
  end

  it "encodes/decodes a token using pub/priv key" do
    tkn = subject.encode(@tkn_body, 'RS256')
    result = subject.decode("bEaReR #{tkn}")
    result.should_not be_nil
    result["foo"].should == "bar"
  end

  it "encodes/decodes a token using pub/priv key from PEM" do
    pem = <<-DATA.gsub(/^ +/, '')
      -----BEGIN RSA PRIVATE KEY-----
      MIIBOwIBAAJBAN+5O6n85LSs/fj46Ht1jNbc5e+3QX+suxVPJqICvuV6sIukJXXE
      zfblneN2GeEVqgeNvglAU9tnm3OIKzlwM5UCAwEAAQJAEhJ2fV7OYsHuqiQBM6fl
      Pp4NfPXCtruPSUNhjYjHPuYpnqo6cpuUNAzRvqAdDkJJsPCPt1E5AWOYUYOmLE+d
      AQIhAO/XxMb9GrTDyqJDvS8T1EcJpLCaUIReae0jSg1RnBrhAiEA7st6WLmOyTxX
      JgLcO6LUfW6RsE3pgi9NGL25P3eOAzUCIQDUFKi1CJR36XWh/GIqYc9grX9KhnnS
      QqZKAd12X4a5IQIhAMTOJKaNP/Xwai7kupfX6mL6Rs5UWDg4PcU/UDbTlNJlAiBv
      2yrlT5h164jGCxqe7++1kIl4ollFCgz6QJ8lcmb/2Q==
      -----END RSA PRIVATE KEY-----
    DATA
    coder = TokenCoder.new(audience_ids: "test_resource", pkey: pem)
    tkn = coder.encode(@tkn_body, 'RS256')
    result = coder.decode("bEaReR #{tkn}")
    result.should_not be_nil
    result["foo"].should == "bar"
  end

  it "encodes/decodes with 'none' signature if explicitly accepted" do
    tkn = subject.encode(@tkn_body, 'none')
    result = TokenCoder.decode(tkn, accept_algorithms: "none")
    result.should_not be_nil
    result["foo"].should == "bar"
  end

  it "rejects a token with 'none' signature by default" do
    tkn = subject.encode(@tkn_body, 'none')
    expect { TokenCoder.decode(tkn) }.to raise_exception(SignatureNotAccepted)
  end

  it "raises an error if the signing algorithm is not supported" do
    expect { subject.encode(@tkn_body, 'baz') }.to raise_exception(SignatureNotSupported)
  end

  it "raises an error if the token is for another resource server" do
    tkn = subject.encode({'aud' => ["other_resource"], 'foo' => "bar"})
    expect { subject.decode("bEaReR #{tkn}") }.to raise_exception(InvalidAudience)
  end

  it "raises an error if the token is signed by an unknown signing key" do
    other = TokenCoder.new(audience_ids: "test_resource", skey: "other_secret")
    tkn = other.encode(@tkn_body)
    expect { subject.decode("bEaReR #{tkn}") }.to raise_exception(InvalidSignature)
  end

  it "raises an error if the token is public-key signed and we try to decode with symmetric key" do
    pem = <<-DATA.gsub(/^ +/, '')
      -----BEGIN RSA PRIVATE KEY-----
      MIIBOwIBAAJBAN+5O6n85LSs/fj46Ht1jNbc5e+3QX+suxVPJqICvuV6sIukJXXE
      zfblneN2GeEVqgeNvglAU9tnm3OIKzlwM5UCAwEAAQJAEhJ2fV7OYsHuqiQBM6fl
      Pp4NfPXCtruPSUNhjYjHPuYpnqo6cpuUNAzRvqAdDkJJsPCPt1E5AWOYUYOmLE+d
      AQIhAO/XxMb9GrTDyqJDvS8T1EcJpLCaUIReae0jSg1RnBrhAiEA7st6WLmOyTxX
      JgLcO6LUfW6RsE3pgi9NGL25P3eOAzUCIQDUFKi1CJR36XWh/GIqYc9grX9KhnnS
      QqZKAd12X4a5IQIhAMTOJKaNP/Xwai7kupfX6mL6Rs5UWDg4PcU/UDbTlNJlAiBv
      2yrlT5h164jGCxqe7++1kIl4ollFCgz6QJ8lcmb/2Q==
      -----END RSA PRIVATE KEY-----
    DATA
    coder = TokenCoder.new(audience_ids: "test_resource", pkey: pem)
    coder2 = TokenCoder.new(audience_ids: "test_resource", skey: 'randomness')

    tkn = coder.encode(@tkn_body, 'RS256')

    expect { coder2.decode("bEaReR #{tkn}") }.to raise_exception(InvalidSignature)
  end

  it "raises an error if the token is symmetric-key signed and we try to decode with a public key" do
    pem = <<-DATA.gsub(/^ +/, '')
      -----BEGIN RSA PRIVATE KEY-----
      MIIBOwIBAAJBAN+5O6n85LSs/fj46Ht1jNbc5e+3QX+suxVPJqICvuV6sIukJXXE
      zfblneN2GeEVqgeNvglAU9tnm3OIKzlwM5UCAwEAAQJAEhJ2fV7OYsHuqiQBM6fl
      Pp4NfPXCtruPSUNhjYjHPuYpnqo6cpuUNAzRvqAdDkJJsPCPt1E5AWOYUYOmLE+d
      AQIhAO/XxMb9GrTDyqJDvS8T1EcJpLCaUIReae0jSg1RnBrhAiEA7st6WLmOyTxX
      JgLcO6LUfW6RsE3pgi9NGL25P3eOAzUCIQDUFKi1CJR36XWh/GIqYc9grX9KhnnS
      QqZKAd12X4a5IQIhAMTOJKaNP/Xwai7kupfX6mL6Rs5UWDg4PcU/UDbTlNJlAiBv
      2yrlT5h164jGCxqe7++1kIl4ollFCgz6QJ8lcmb/2Q==
      -----END RSA PRIVATE KEY-----
    DATA
    coder = TokenCoder.new(audience_ids: "test_resource", pkey: pem)
    coder2 = TokenCoder.new(audience_ids: "test_resource", skey: 'randomness')
    tkn = coder2.encode(@tkn_body)

    expect { coder.decode("bEaReR #{tkn}") }.to raise_exception(InvalidSignature)
  end

  it "raises an error if the token is an unknown signing algorithm" do
    segments = [Util.json_encode64(typ: "JWT", alg:"BADALGO")]
    segments << Util.json_encode64(@tkn_body)
    segments << Util.encode64("BADSIG")
    tkn = segments.join('.')
    tc = TokenCoder.new(audience_ids: "test_resource",
        skey: "test_secret", pkey: OpenSSL::PKey::RSA.generate(512),
        accept_algorithms: "BADALGO")
    expect { tc.decode("bEaReR #{tkn}") }.to raise_exception(SignatureNotSupported)
  end

  it "raises an error if the token is malformed" do
    tkn = "one.two.three.four"
    expect { subject.decode("bEaReR #{tkn}") }.to raise_exception(InvalidTokenFormat)
    tkn = "onlyone"
    expect { subject.decode("bEaReR #{tkn}") }.to raise_exception(InvalidTokenFormat)
  end

  it "raises a decode error if a token segment is malformed" do
    segments = [Util.encode64("this is not json")]
    segments << Util.encode64("n/a")
    segments << Util.encode64("n/a")
    tkn = segments.join('.')
    expect { subject.decode("bEaReR #{tkn}") }.to raise_exception(DecodeError)
  end

  context "when the implied expiration check is now" do
    it "raises an error if the token has expired" do
      tkn = subject.encode({'foo' => "bar", 'exp' => Time.now.to_i - 60 })
      expect { subject.decode("bEaReR #{tkn}") }.to raise_exception(TokenExpired)
    end
  end

  context "when an explicit time stamp is provided for the expiration check" do
    it "raises an error if the token was expired at the specified time" do
      tkn = subject.encode({'foo' => "bar", 'exp' => Time.now.to_i - 30 })
      expect { subject.decode_at_reference_time("bEaReR #{tkn}", Time.now.to_i - 20) }.to raise_exception(TokenExpired)
    end

    it "returns the decoded token if it was valid at the specified time" do
      tkn = subject.encode({'foo' => "bar", 'exp' => Time.now.to_i - 30 })
      result = subject.decode_at_reference_time("bEaReR #{tkn}", Time.now.to_i - 100)
      result.should_not be_nil
      result["foo"].should == "bar"
    end
  end

  it "decodes a token without validation" do
    token = "eyJhbGciOiJIUzI1NiJ9.eyJpZCI6ImY1MTgwMjExLWVkYjItNGQ4OS1hNmQwLThmNGVjMTE0NTE4YSIsInJlc291cmNlX2lkcyI6WyJjbG91ZF9jb250cm9sbGVyIiwicGFzc3dvcmQiXSwiZXhwaXJlc19hdCI6MTMzNjU1MTc2Niwic2NvcGUiOlsicmVhZCJdLCJlbWFpbCI6Im9sZHNAdm13YXJlLmNvbSIsImNsaWVudF9hdXRob3JpdGllcyI6WyJST0xFX1VOVFJVU1RFRCJdLCJleHBpcmVzX2luIjo0MzIwMCwidXNlcl9hdXRob3JpdGllcyI6WyJST0xFX1VTRVIiXSwidXNlcl9pZCI6Im9sZHNAdm13YXJlLmNvbSIsImNsaWVudF9pZCI6InZtYyIsInRva2VuX2lkIjoiZWRlYmYzMTctNWU2Yi00YmYwLWFmM2ItMTA0OWRjNmFlYjc1In0.XoirrePfEujnZ9Vm7SRRnj3vZEfRp2tkjkS_OCVz5Bs"
    info = TokenCoder.decode(token, verify: false)
    info["id"].should_not be_nil
    info["email"].should == "olds@vmware.com"
  end

  it "decodes only the expiry_at time" do
    exp = Time.now.to_i + 60
    tkn = subject.encode({'foo' => "bar", 'exp' => exp })
    TokenCoder.decode_token_expiry("bEaReR #{tkn}").should == exp
  end
end

end
