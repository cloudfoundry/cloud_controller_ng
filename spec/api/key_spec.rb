# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController

  describe VCAP::CloudController do
    describe "signing key" do

      before(:all) do
        @privkey2 = "
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEApTHZtG0TtKIth3EvgNcE9blWh6h+WGVuuFNreAk6ABSh/e0Q
xcyWhSFVERSly9Zvo61ElPGcA/vTZY7VLTux0gQDjR6GFa21FEnzt2xoauO1JbzM
qYvFo2HQAKi810IeCl6KxL+tlRjcgpgy11XGg2XTgHFvJxb2gicD9KbzZY/DbNjV
H9GHm6p5ZXqO6Afbx48/O9ZCZ/Jgdw0BkbM8xjCkSA+aGPOY+iVlYrsA/spgAsc9
3wb5HKgwh/R80iNFr9I0h9XPKEbpREeKO/ItMH90yulOrLzmPEso+OTKpijqxOqe
qB7INDRmymnPUaxJPH9RB1GMPOqHa36LFzyy4wIDAQABAoIBAAhcZo1oO+gXkUBa
rTHTMDATqlqBX6uvrpPrvPO9W88nPC+y8Pdh7HhegIS1y9JuTwY0vdTgCap183Qf
b5CzhcOAaoGY+uZb/V9CgvBUr1BBqCh5zs4CAgXL7JAr+irW8NhLgrCElw+Fy5tc
gq49bCe4XqUQmLScx+s8eEnIrWcFc+MV98TN50hStAO7dET2S0woFV6qv3eT1Om6
jP7qeYvTSPrFurAyFHHmgohCzddnTKuFw+VAcKGrc63PsIke9TVFH8fsVBIYUm4c
odpVzY1EnW6HqE5zWl7uDjErf3ll1hodPPy3RGJmKTgFV6jz5P9ZbUEJZSnXMFm1
QWyd4AECgYEA1zLPZQqd7vColWVFOcBayK4KjGaRxxBCQDtDkkxHiV0PH4XO7Aph
0gU68oGhWCqmuzoKRJ+IdmCChFa0cwr7JsCSrsBvA8vrXosgOyEqqW2jHhOGz8ww
qRmEoe+LF7FwewKRrstI+k12Jj5RPDKl776WA7hoOAxYoybGEakWouMCgYEAxIP8
GOOZ7Yvn2wO469oRimHhz98PX3TC16SPG/W8jEIXgB+pJMNC7cdiWajjePZRe1pq
vyGtcauMI2mP0Et6rRREnMY8RQm/I2zljlDoZryYrTjOP7yvrWiC/LdBuV6pgKo9
1vAIbOoFDdPATrfy+1DOeX7dvJf2IaIPNl9OsAECgYA98TIhM10iWcMsvWmfpe57
tRz0LNHpKpTnSCe7BJnSwCaKPEnDR3nAqiC9jPKUHjK/0YUDG6h76munDA4EzzRb
gzK1ek56GUg2fnVYj8Nn4VcCYTx8s5mOEvpKYlj3COwHfEXSulDXO1S2zVk0qp94
0rL7fykAeQ1KaO66RqFtYQKBgQC/ZmmoeC2ZLzXgnCyFEr0Y0iMUyoX3jAql67Iz
IlHFLi4jbTLaCpBqdVL2TsdXLlnIUhU8GXoMB3CToSIgVxOh9eap524WM9sFju+6
gFUKk1AFDxna/FUDCZLivz51ZJylI6rdaKZcJkZL5F0ejo1Ld7XSod0n7b4dnfFB
HOzQAQKBgQCivYz9hLu1flkVGnaB93IpE/0DohQOTthcOFfJ8uNIPLqOeBBCTdui
Ed2Kj/FxENijeU6LOElXqEPvOiFlFXHFxfzMIODYMlARiiDfYEcyPvrfMorR43f8
miiTjbON505edx3q6KWNSb9ODav2iDNHl5yFLefpJISpqQarE47DGQ==
-----END RSA PRIVATE KEY-----
            "
        @pubkey2 = "
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApTHZtG0TtKIth3EvgNcE
9blWh6h+WGVuuFNreAk6ABSh/e0QxcyWhSFVERSly9Zvo61ElPGcA/vTZY7VLTux
0gQDjR6GFa21FEnzt2xoauO1JbzMqYvFo2HQAKi810IeCl6KxL+tlRjcgpgy11XG
g2XTgHFvJxb2gicD9KbzZY/DbNjVH9GHm6p5ZXqO6Afbx48/O9ZCZ/Jgdw0BkbM8
xjCkSA+aGPOY+iVlYrsA/spgAsc93wb5HKgwh/R80iNFr9I0h9XPKEbpREeKO/It
MH90yulOrLzmPEso+OTKpijqxOqeqB7INDRmymnPUaxJPH9RB1GMPOqHa36LFzyy
4wIDAQAB
-----END PUBLIC KEY-----
            "
      end

      before(:all) do
        @user = Models::User.make(:admin => true, :guid => 'abcd-efgh')
        @email = "user_x@vmware.com"
      end

      before(:each) do
        # start with a clean slate
        Redis.new.flushall
      end

      it "should use the configured signing key" do
        headers = headers_for(@user, :email => @email)

        get "/users/#{@email}", {}, headers
        last_response.status.should == 200
      end

      it "caches a new signing key if it successfully decodes" do
        headers = headers_for(@user, :signing_key => @privkey2, :email => @email)
        CF::UAA::Misc.stub(:validation_key).and_return('value' => @pubkey2)

        get "/users/#{@email}", {}, headers
        last_response.status.should == 200
        Redis.new.get("cc.verification_key").should == @pubkey2
      end

      it "should not immediately recontact the uaa" do
        # asks the UAA if it has a pub key up front
        headers = headers_for(@user, :email => @email)
        get "/users/#{@email}", {}, headers
        last_response.status.should == 200

        # auth should fail without contacting UAA again
        headers = headers_for(@user, :signing_key => @privkey2, :email => @email)
        CF::UAA::Misc.expects(:validation_key).never
        get "/users/#{@email}", {}, headers
        last_response.status.should == 403
      end

      it "fails if new key cannot decode" do
        headers = headers_for(@user, :signing_key => @privkey2, :email => @email)
        CF::UAA::Misc.stub(:validation_key).and_return('value' => 'nonsense')

        get "/users/#{@email}", {}, headers
        last_response.status.should == 403
      end
    end
  end
end

