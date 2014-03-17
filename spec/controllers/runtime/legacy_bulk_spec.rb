require "spec_helper"
require "membrane"
require "json_message"
require "cf_message_bus/mock_message_bus"

module VCAP::CloudController
  describe LegacyBulk, type: :controller do
    let(:mbus) { CfMessageBus::MockMessageBus.new({}) }

    before do
      @bulk_user = "bulk_user"
      @bulk_password = "bulk_password"
    end

    describe ".register_subscription" do
      it "should be able to discover credentials through message bus" do
        LegacyBulk.configure(config, mbus)

        mbus.should_receive(:subscribe)
          .with("cloudcontroller.bulk.credentials.ng")
          .and_yield("xxx", "inbox")

        mbus.should_receive(:publish).with("inbox", anything) do |_, msg|
          msg.should == {
            "user"      => @bulk_user,
            "password"  => @bulk_password,
          }
        end

        LegacyBulk.register_subscription
      end
    end

    describe "GET", "/bulk/apps" do
      before { 5.times { AppFactory.make } }

      it "requires authentication" do
        get "/bulk/apps"
        last_response.status.should == 401

        authorize "bar", "foo"
        get "/bulk/apps"
        last_response.status.should == 401
      end

      describe "with authentication" do
        before do
          authorize @bulk_user, @bulk_password
        end

        it "requires a token in query string" do
          get "/bulk/apps"
          last_response.status.should == 400
        end

        it "returns nil bulk_token for the initial request" do
          get "/bulk/apps"
          decoded_response["bulk_token"].should be_nil
        end

        it "returns a populated bulk_token for the initial request (which has an empty bulk token)" do
          get "/bulk/apps", {
            "batch_size" => 20,
            "bulk_token" => "{}",
          }
          decoded_response["bulk_token"].should_not be_nil
        end

        it "returns results in the response body" do
          get "/bulk/apps", {
            "batch_size" => 20,
            "bulk_token" => "{\"id\":20}",
          }
          last_response.status.should == 200
          decoded_response["results"].should_not be_nil
        end

        it "returns results that are valid json" do
          get "/bulk/apps", {
            "batch_size" => 100,
            "bulk_token" => "{\"id\":0}",
          }
          last_response.status.should == 200
          decoded_response["results"].each { |key,value|
            value.should be_kind_of Hash
            value["id"].should_not be_nil
            value["version"].should_not be_nil
          }
        end

        it "respects the batch_size parameter" do
          [3,5].each { |size|
            get "/bulk/apps", {
              "batch_size" => size,
              "bulk_token" => "{\"id\":0}",
            }
            decoded_response["results"].size.should == size
          }
        end

        it "returns non-intersecting results when token is supplied" do
          get "/bulk/apps", {
            "batch_size" => 2,
            "bulk_token" => "{\"id\":0}",
          }
          saved_results = decoded_response["results"].dup
          saved_results.size.should == 2

          get "/bulk/apps", {
            "batch_size" => 2,
            "bulk_token" => Yajl::Encoder.encode(decoded_response["bulk_token"]),
          }
          new_results = decoded_response["results"].dup
          new_results.size.should == 2
          saved_results.each do |saved_result|
            new_results.should_not include(saved_result)
          end
        end

        it "should eventually return entire collection, batch after batch" do
          apps = {}
          total_size = App.count

          token = "{}"
          while apps.size < total_size do
            get "/bulk/apps", {
              "batch_size" => 2,
              "bulk_token" => Yajl::Encoder.encode(token),
            }
            last_response.status.should == 200
            token = decoded_response["bulk_token"]
            apps.merge!(decoded_response["results"])
          end

          apps.size.should == total_size
          get "/bulk/apps", {
            "batch_size" => 2,
            "bulk_token" => Yajl::Encoder.encode(token),
          }
          decoded_response["results"].size.should == 0
        end
      end
    end

    describe "GET", "/bulk/counts" do
      it "requires authentication" do
        get "/bulk/counts", {"model" => "user"}
        last_response.status.should == 401
      end

      it "returns the number of users" do
        4.times { User.make }
        authorize @bulk_user, @bulk_password
        get "/bulk/counts", {"model" => "user"}
        decoded_response["counts"].should include("user" => kind_of(Integer))
        decoded_response["counts"]["user"].should == User.count
      end
    end
  end
end