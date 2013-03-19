# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "vcap/uaa_util"

module VCAP
  describe UaaUtil do
    subject do
      Class.new do
        include UaaUtil

        attr_reader :config
        attr_reader :logger

        def initialize(config)
          @config = config
          @logger = Logger.new("/dev/null")
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

        it "uses UAA::TokenCoder to decode the token with skey" do
          coder = mock(:token_coder)
          coder.should_receive(:decode).with("bearer token")

          CF::UAA::TokenCoder.should_receive(:new).with(
            :audience_ids => "resource-id",
            :skey => "symmetric-key",
          ).and_return(coder)

          subject.decode_token("bearer token")
        end
      end

      context "when asymmetric secret key is used" do
        before { config_hash[:uaa][:symmetric_secret] = nil }

        before { CF::UAA::Misc.stub(:validation_key => {"value" => "asymmetric-key"}) }
        after { Timecop.return }

        it "uses UAA::TokenCoder to decode token with pkey" do
          Timecop.freeze(Time.now)

          coder = mock(:token_coder)
          coder.should_receive(:decode)
            .with("bearer token")
            .any_number_of_times
            .and_return("decoded-token")

          CF::UAA::TokenCoder.should_receive(:new).with(
            :audience_ids => "resource-id",
            :pkey => "asymmetric-key",
          ).and_return(coder)

          CF::UAA::Misc.should_receive(:validation_key)
          subject.decode_token("bearer token").should == "decoded-token"

          # Make sure that cached key is not too new to replace
          Timecop.freeze(Time.now.to_i + UaaUtil::MIN_KEY_AGE - 1)

          CF::UAA::TokenCoder.should_receive(:new).with(
            :audience_ids => "resource-id",
            :pkey => "asymmetric-key",
          ).and_return(coder)

          CF::UAA::Misc.should_not_receive(:validation_key)
          subject.decode_token("bearer token").should == "decoded-token"
        end
      end
    end
  end
end
