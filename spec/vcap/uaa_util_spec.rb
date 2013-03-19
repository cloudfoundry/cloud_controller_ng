# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "vcap/uaa_util"
require "openssl"

module VCAP
  describe UaaUtil do
    subject do
      Class.new do
        include UaaUtil
        attr_reader :config

        def initialize(config)
          @config = config
        end
      end.new(config_hash)
    end

    let(:config_hash) do
      {:redis => {},
       :uaa => {
        :resource_id => "resource-id",
        :symmetric_secret => nil,
      }}
    end

    describe "#decode_token" do
      context "when symmetric key is used" do
        before { config_hash[:uaa][:symmetric_secret] = "symmetric-key" }

        context "when toke is valid" do
          it "uses UAA::TokenCoder to decode the token with skey" do
            coder = mock(:token_coder)
            coder.should_receive(:decode)
              .with("bearer token")
              .and_return("decoded-info")

            CF::UAA::TokenCoder.should_receive(:new).with(
              :audience_ids => "resource-id",
              :skey => "symmetric-key",
            ).and_return(coder)

            subject.decode_token("bearer token").should == "decoded-info"
          end
        end

        context "when token is invalid" do
          it "raises UAAError exception" do
            expect {
              subject.decode_token("bearer token")
            }.to raise_error(CF::UAA::UAAError)
          end
        end
      end

      context "when asymmetric key is used" do
        before { config_hash[:uaa][:symmetric_secret] = nil }

        before { Timecop.freeze(Time.now) }
        after { Timecop.return }

        let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
        before { CF::UAA::Misc.stub(:validation_key => {"value" => rsa_key.public_key.to_pem}) }

        context "when token is valid" do
          let(:token_content) do
            {"aud" => "resource-id", "payload" => 123, "exp" => Time.now.to_i + 10_000}
          end

          it "successfully decodes token and caches key" do
            token = generate_token(rsa_key, token_content)

            CF::UAA::Misc.should_receive(:validation_key)
            subject.decode_token("bearer #{token}").should == token_content

            CF::UAA::Misc.should_not_receive(:validation_key)
            subject.decode_token("bearer #{token}").should == token_content
          end

          describe "re-fetching key" do
            let(:old_rsa_key) { OpenSSL::PKey::RSA.new(2048) }

            it "retries to decode token with newly fetched asymmetric key" do
              CF::UAA::Misc
                .stub(:validation_key)
                .and_return(
                  {"value" => old_rsa_key.public_key.to_pem},
                  {"value" => rsa_key.public_key.to_pem},
                )
              subject.decode_token("bearer #{generate_token(rsa_key, token_content)}").should == token_content
            end

            it "stops retrying to decode token with newly fetched asymmetric key after 1 try" do
              CF::UAA::Misc
                .stub(:validation_key)
                .and_return("value" => old_rsa_key.public_key.to_pem)

              expect {
                subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
              }.to raise_error(CF::UAA::InvalidSignature)
            end
          end
        end

        context "when token has invalid audience" do
          let(:token_content) do
            {"aud" => "invalid-audience", "payload" => 123, "exp" => Time.now.to_i + 10_000}
          end

          it "raises an InvalidAudience error" do
            expect {
              subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
            }.to raise_error(CF::UAA::InvalidAudience)
          end
        end

        context "when token has expired" do
          let(:token_content) do
            {"aud" => "resource-id", "payload" => 123, "exp" => Time.now.to_i}
          end

          it "raises an error" do
            expect {
              subject.decode_token("bearer #{generate_token(rsa_key, token_content)}")
            }.to raise_error(CF::UAA::TokenExpired)
          end
        end

        context "when token is invalid" do
          it "raises error" do
            expect {
              subject.decode_token("bearer invalid-token")
            }.to raise_error(CF::UAA::InvalidTokenFormat)
          end
        end

        def generate_token(rsa_key, content)
          CF::UAA::TokenCoder.encode(content, {
            :pkey => rsa_key,
            :algorithm => "RS256",
          })
        end
      end
    end
  end

  describe UaaUtil::UaaVerificationKey do
    let(:config_hash) do
      { :url => "http://uaa-url" }
    end

    subject do
      UaaUtil::UaaVerificationKey.new(config_hash)
    end

    describe "#value" do
      context "when config does not specify verification key" do
        before { config_hash[:verification_key] = nil }
        before { CF::UAA::Misc.stub(:validation_key => {"value" => "value-from-uaa"}) }

        context "when key was never fetched" do
          it "is fetched" do
            CF::UAA::Misc.should_receive(:validation_key).with("http://uaa-url")
            subject.value.should == "value-from-uaa"
          end
        end

        context "when key was fetched before" do
          before do
            CF::UAA::Misc.should_receive(:validation_key) # sanity
            subject.value
          end

          it "is not fetched again" do
            CF::UAA::Misc.should_not_receive(:validation_key)
            subject.value.should == "value-from-uaa"
          end
        end
      end

      context "when config specified verification key" do
        before { config_hash[:verification_key] = "value-from-config" }

        it "returns key specified in config" do
          subject.value.should == "value-from-config"
        end

        it "is not fetched" do
          CF::UAA::Misc.should_not_receive(:validation_key)
          subject.value
        end
      end
    end

    describe "#refresh" do
      context "when config does not specify verification key" do
        before { config_hash[:verification_key] = nil }
        before { CF::UAA::Misc.stub(:validation_key => {"value" => "value-from-uaa"}) }

        context "when key was never fetched" do
          it "is fetched" do
            CF::UAA::Misc.should_receive(:validation_key).with("http://uaa-url")
            subject.refresh
            subject.value.should == "value-from-uaa"
          end
        end

        context "when key was fetched before" do
          before do
            CF::UAA::Misc.should_receive(:validation_key) # sanity
            subject.value
          end

          it "is RE-fetched again" do
            CF::UAA::Misc.should_receive(:validation_key).with("http://uaa-url")
            subject.refresh
            subject.value.should == "value-from-uaa"
          end
        end
      end

      context "when config specified verification key" do
        before { config_hash[:verification_key] = "value-from-config" }

        it "returns key specified in config" do
          subject.refresh
          subject.value.should == "value-from-config"
        end

        it "is not fetched" do
          CF::UAA::Misc.should_not_receive(:validation_key)
          subject.refresh
          subject.value.should == "value-from-config"
        end
      end
    end
  end
end
