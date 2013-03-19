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
      end.new(config)
    end

    describe "#decode_token" do
      context "when symmetric secret key is used" do
        let(:config) { {:uaa => {:resource_id => "resource-id", :symmetric_secret => "symmetric-key"}} }

        it "uses UAA::TokenCoder to decode the token with skey" do
          coder = mock(:token_coder)
          coder.should_receive(:decode).with("BEARER token")

          CF::UAA::TokenCoder.should_receive(:new).with(
            :audience_ids => "resource-id",
            :skey => "symmetric-key",
          ).and_return(coder)

          subject.decode_token("BEARER token")
        end
      end

      context "when asymmetric secret key is used" do
        let(:config) { {:redis => {}, :uaa => {:resource_id => "resource-id"}} }

        before { CF::UAA::Misc.stub(:validation_key => {"value" => "asymmetric-key"}) }

        it "uses UAA::TokenCoder to decode token with pkey" do
          coder = mock(:token_coder)
          coder.should_receive(:decode).with("BEARER token")

          CF::UAA::TokenCoder.should_receive(:new).with(
            :audience_ids => "resource-id",
            :pkey => "asymmetric-key",
          ).and_return(coder)

          subject.decode_token("BEARER token")
        end
      end

    end
  end
end
