# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::RestController::QuotaManager do
    describe "with_quota_enforcement" do
      # since we are mocking the fetch, we don't really need a body
      let (:quota_body) { {:foo => "bar"} }

      context "Errors::QuotaDeclined returned from fetch_quota_token" do
        it "should raise a QuotaDeclined error" do
          body_called = false

          RestController::QuotaManager.should_receive(:fetch_quota_token).
            and_raise(Errors::QuotaDeclined.new("over limit"))

          expect do
            RestController::QuotaManager.with_quota_enforcement(quota_body) do
              body_called = true
            end
          end.to raise_error(Errors::QuotaDeclined, /over limit/)

          body_called.should be_false
        end
      end

      context "a token returned erom fetch_quota_token" do
        it "should call the supplied block and commit the token" do
          token = mock(:token)
          token.should_receive(:commit)

          RestController::QuotaManager.should_receive(:fetch_quota_token).
            and_return(token)

          body_called = false
          ret = RestController::QuotaManager.with_quota_enforcement(quota_body) do
            body_called = true
            123
          end
          body_called.should be_true
          ret.should == 123
        end
      end

      context "error during block processing" do
        it "should call token.abandon and re-raise the error" do
          token = mock(:token)
          token.should_receive(:abandon).with("boom")

          RestController::QuotaManager.should_receive(:fetch_quota_token).
            and_return(token)

          expect do
            RestController::QuotaManager.with_quota_enforcement(quota_body) do
              raise "boom"
            end
          end.to raise_error("boom")
        end
      end

      context "error while commiting the token" do
        it "should log an error but not call token.abandon" do
          RestController::QuotaManager.logger.should_receive(:error)

          token = mock(:token)
          token.should_receive(:commit).and_raise("bang")

          RestController::QuotaManager.should_receive(:fetch_quota_token).
            and_return(token)

          RestController::QuotaManager.with_quota_enforcement(quota_body) {}
        end
      end
    end
  end

  describe VCAP::CloudController::RestController::QuotaManager::MoneyMakerClient do
    describe "request" do
      it "should send X-VCAP-Request_ID" do
        request_guid = SecureRandom.uuid
        Thread.current[:vcap_request_id] = request_guid

        client = mock(:http_client)
        url = "http://some/url"
        body = { :foo => "bar" }

        client.should_receive(:request) do |m, u, opts|
          m.should == :post
          u.should == url
          opts[:body].should == Yajl::Encoder.encode(body)
          opts[:header]["x-vcap-request-id"].should == request_guid
          OpenStruct.new(:code => 200, :body => "")
        end

        RestController::QuotaManager::MoneyMakerClient.
          should_receive(:http_client).and_return(client)

        RestController::QuotaManager::MoneyMakerClient.
          send(:request, :post, url, body)
      end
    end
  end
end
