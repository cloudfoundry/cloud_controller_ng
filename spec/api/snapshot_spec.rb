require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Snapshots do
    let(:service_instance) do
      service = Models::Service.make(
        :url => "http://horsemeat.com",
      )
      Models::ServiceInstance.make(
        :service_plan => Models::ServicePlan.make(:service => service),
      )
    end

    describe "POST", "/v2/snapshots" do
      let(:new_name) { 'new name' }
      let(:snapshot_created_at) { Time.now.to_s }
      let(:new_snapshot) { VCAP::Services::Api::SnapshotV2.new(snapshot_id: '1', name: 'foo', state: 'empty', size: 0, created_time: snapshot_created_at)}
      let(:payload) {
        Yajl::Encoder.encode(:service_instance_guid => service_instance.guid,
                             :name => new_name)
      }

      before do
        url = "http://horsemeat.com/gateway/v2/configurations/#{service_instance.gateway_name}/snapshots"
        stub_request(:post, url).to_return(:status => 201, :body => new_snapshot.encode)
      end

      context "for an unauthenticated user" do
        it "requires authentication" do
          post "/v2/snapshots", payload, {}
          last_response.status.should == 401
          a_request(:any, %r(http://horsemeat.com)).should_not have_been_made
        end
      end

      context "for an admin" do
        let(:admin_headers) do
          user = Models::User.make(:admin => true)
          headers_for(user)
        end

        it "should allow them to create a snapshot" do
          post "/v2/snapshots", payload, admin_headers
          last_response.status.should == 201
        end
      end

      context "for a developer not in the space" do
        let(:another_space) { Models::Space.make }
        let(:developer) { make_developer_for_space(another_space) }
        it "denies access" do
          post "/v2/snapshots", payload, headers_for(developer)
          last_response.status.should eq 403
          a_request(:any, %r(http://horsemeat.com)).should_not have_been_made
        end
      end

      context "once authenticated" do
        let(:developer) {make_developer_for_space(service_instance.space)}

        context "without service_instance_id" do
          it "returns a 400 status code" do
            post "/v2/snapshots", '{}', headers_for(developer)
            last_response.status.should == 400
          end

          it "does not create a snapshot" do
            Models::ServiceInstance.any_instance.should_not_receive(:create_snapshot)
            post "/v2/snapshots", '{}', headers_for(developer)
            a_request(:any, %r(http://horsemeat.com)).should_not have_been_made
          end
        end

        context "given nil name" do
          let(:new_name) {nil}

          it "returns a 400 status code and does not create a snapshot" do
            Models::ServiceInstance.any_instance.should_not_receive(:create_snapshot)
            post "/v2/snapshots", payload, headers_for(developer)
            last_response.status.should == 400
            a_request(:any, %r(http://horsemeat.com)).should_not have_been_made
          end
        end

        context "with a blank name" do
          let(:new_name) {""}
          it "returns a 400 status code and does not create a snapshot" do
            post "/v2/snapshots", payload, headers_for(developer)
            last_response.status.should == 400
            a_request(:any, %r(http://horsemeat.com)).should_not have_been_made
          end
        end

        it "invokes create_snapshot on the corresponding service instance" do
          Models::ServiceInstance.should_receive(:find).
            with(:guid => service_instance.guid).
            and_return(service_instance)
          service_instance.should_receive(:create_snapshot).with(new_name)
          post "/v2/snapshots", payload, headers_for(developer)
        end

        context "when the gateway successfully creates the snapshot" do
          it "returns the details of the new snapshot" do
            post "/v2/snapshots", payload, headers_for(developer)
            last_response.status.should == 201
            snapguid = "#{service_instance.guid}_1"
            decoded_response['metadata'].should == {
              "guid" => snapguid,
              "url" => "/v2/snapshots/#{snapguid}",
              "created_at" => snapshot_created_at,
              "updated_at" => nil
            }
            decoded_response['entity'].should include({"state" => "empty", "name" => "foo"})
          end
        end
      end
    end

    describe "GET /v2/service_instances/:service_id/snapshots" do
      let(:snapshots_url) {  "/v2/service_instances/#{service_instance.guid}/snapshots" }

      it 'requires authentication' do
        get snapshots_url
        last_response.status.should == 401
        a_request(:any, %r(http://horsemeat.com)).should_not have_been_made
      end

      context "once authenticated" do
        let(:developer) {make_developer_for_space(service_instance.space)}
        before do
          Models::ServiceInstance.stub(:find).
            with(:guid => service_instance.guid).
            and_return(service_instance)
        end

        it "returns an empty list" do
          service_instance.stub(:enum_snapshots).and_return []
          get snapshots_url, {} , headers_for(developer)
          last_response.status.should == 200
          decoded_response['resources'].should == []
        end

        it "returns an list of snapshots" do
          created_time = Time.now.to_s
          service_instance.should_receive(:enum_snapshots) do
            [VCAP::Services::Api::SnapshotV2.new(
              "snapshot_id" => "1234",
              "name" => "something",
              "state" => "empty",
              "size" => 0,
              "created_time" => created_time)
            ]
          end
          get snapshots_url, {} , headers_for(developer)
          decoded_response.should == {
            "total_results" => 1,
            "total_pages" => 1,
            "prev_url" => nil,
            "next_url" => nil,
            "resources"=>[
              {
                "metadata" => {
                  "guid" => "#{service_instance.guid}_1234",
                  "url" => "/v2/snapshots/#{service_instance.guid}_1234",
                  "created_at" => created_time,
                  "updated_at" => nil
                },
                "entity" => {
                  "snapshot_id" => "1234", "name" => "something", "state" => "empty", "size" => 0, "created_time" => created_time
                }
              }
            ]
          }
          last_response.status.should == 200
        end

        it "checks for permission to read the service" do
          another_developer   =  make_developer_for_space(Models::Space.make)
          get snapshots_url, {} , headers_for(another_developer)
          last_response.status.should == 403
        end
      end
    end
  end
end
