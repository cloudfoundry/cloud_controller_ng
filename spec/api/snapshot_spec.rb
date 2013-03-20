require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Snapshots do
    let(:service_instance) do
      Models::ServiceInstance.make
    end

    describe "POST", "/v2/snapshots" do
      let(:new_name) { 'new name' }
      let(:new_snapshot) { VCAP::Services::Api::SnapshotV2.new(snapshot_id: '1', name: 'foo', state: 'empty', size: 0)}
      let(:payload) {
        Yajl::Encoder.encode(:service_instance_guid => service_instance.guid,
                             :name => new_name)
      }
      before do
        Models::ServiceInstance.any_instance.stub(:create_snapshot).and_return(new_snapshot)
      end

      context "for an unauthenticated user" do
        it "requires authentication" do
          post "/v2/snapshots", payload, {}
          last_response.status.should == 401
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
            snapguid = "#{service_instance.guid}:1"
            decoded_response['metadata'].should == {"guid" => snapguid, "url" => "/v2/snapshots/#{snapguid}"}
            decoded_response['entity'].should == {"guid" => snapguid, "state" => "empty"}
          end
        end
      end
    end

    describe "GET /v2/service_instances/:service_id/snapshots" do
      let(:snapshots_url) {  "/v2/service_instances/#{service_instance.guid}/snapshots" }

      it 'requires authentication' do
        get snapshots_url
        last_response.status.should == 401
      end

      context "once authenticated" do
        let(:developer) {make_developer_for_space(service_instance.space)}
        before do
          Models::ServiceInstance.should_receive(:find).
            with(:guid => service_instance.guid).
            and_return(service_instance)
        end

        it "returns an empty list" do
          service_instance.stub(:enum_snapshots).and_return []
          get snapshots_url, {} , headers_for(developer)
          last_response.status.should == 200
          decoded_response['resources'].should == []
        end

        it "returns an list of snpashots" do
          service_instance.should_receive(:enum_snapshots) do
            [{"guid" => '1234', "url" => "/v2/snapshots/1234"}]
          end
          get snapshots_url, {} , headers_for(developer)
          last_response.status.should == 200
          decoded_response['resources'].should == ["guid" => '1234', "url" => "/v2/snapshots/1234"]
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
