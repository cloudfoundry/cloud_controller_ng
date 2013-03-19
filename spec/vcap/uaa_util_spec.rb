# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "vcap/uaa_util"

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
      context "when symmetric secret key is used" do
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

      context "when asymmetric secret key is used" do
        before { config_hash[:uaa][:symmetric_secret] = nil }
        before { CF::UAA::Misc.stub(:validation_key => {"value" => "asymmetric-key"}) }

        context "when token is valid" do
          it "uses UAA::TokenCoder to decode token with pkey" do
            coder = mock(:token_coder)
            coder.should_receive(:decode)
              .with("bearer token")
              .any_number_of_times
              .and_return("decoded-info")

            CF::UAA::TokenCoder.should_receive(:new).with(
              :audience_ids => "resource-id",
              :pkey => "asymmetric-key",
            ).and_return(coder)

            CF::UAA::Misc.should_receive(:validation_key)
            subject.decode_token("bearer token").should == "decoded-info"

            CF::UAA::TokenCoder.should_receive(:new).with(
              :audience_ids => "resource-id",
              :pkey => "asymmetric-key",
            ).and_return(coder)

            CF::UAA::Misc.should_not_receive(:validation_key)
            subject.decode_token("bearer token").should == "decoded-info"
          end

          context "when assymetric key cannot be used to decode token" do
            it "retries to decode token with newly fetched good asymmetric key" do
              CF::UAA::Misc.stub(:validation_key).and_return(
                {"value" => "bad-asymmetric-key"},
                {"value" => "good-asymmetric-key"},
              )

              failed_coder = mock(:token_coder)
              failed_coder.should_receive(:decode)
                .with("bearer token")
                .any_number_of_times
                .and_raise(CF::UAA::InvalidSignature)

              successful_coder = mock(:token_coder)
              successful_coder.should_receive(:decode)
                .with("bearer token")
                .any_number_of_times
                .and_return("decoded-info")

              CF::UAA::TokenCoder.should_receive(:new).with(
                :audience_ids => "resource-id",
                :pkey => "bad-asymmetric-key",
              ).and_return(failed_coder)

              CF::UAA::TokenCoder.should_receive(:new).with(
                :audience_ids => "resource-id",
                :pkey => "good-asymmetric-key",
              ).and_return(successful_coder)

              subject.decode_token("bearer token").should == "decoded-info"
            end

            it "stops retrying to decode token with newly fetched bad asymmetric key" do
              CF::UAA::Misc.stub(:validation_key).and_return({"value" => "bad-asymmetric-key"})

              failed_coder = mock(:token_coder)
              failed_coder.should_receive(:decode)
                .with("bearer token")
                .any_number_of_times
                .and_raise(CF::UAA::InvalidSignature)

              CF::UAA::TokenCoder.should_receive(:new).with(
                :audience_ids => "resource-id",
                :pkey => "bad-asymmetric-key",
              ).any_number_of_times.and_return(failed_coder)

              expect {
                subject.decode_token("bearer token")
              }.to raise_error(CF::UAA::InvalidSignature)
            end
          end
        end

        context "when token is invalid" do
          it "raises error" do
            expect {
              subject.decode_token("bearer token")
            }.to raise_error(OpenSSL::PKey::RSAError)
          end
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
