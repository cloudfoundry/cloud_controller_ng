require "spec_helper"

def generate_hm_api_response(app, running_instances, crash_counts=[])
  result = {
    droplet: app.guid,
    version: app.version,
    desired: {
      id: app.guid,
      version: app.version,
      instances: app.instances,
      memory: app.memory,
      state: app.state,
      package_state: app.package_state,
      updated_at: app.updated_at
    },
    instance_heartbeats: [],
    crash_counts: []
  }

  running_instances.each do |running_instance|
    result[:instance_heartbeats].push({
                                        cc_partition: "default",
                                        droplet: app.guid,
                                        version: app.version,
                                        instance: running_instance[:instance_guid] || Sham.guid,
                                        index: running_instance[:index],
                                        state: running_instance[:state],
                                        state_timestamp: 3.141
                                      })
  end

  crash_counts.each do |crash_count|
    result[:crash_counts].push({
                                  droplet: app.guid,
                                  version: app.version,
                                  instance_index: crash_count[:instance_index],
                                  crash_count: crash_count[:crash_count],
                                  first_crash_time: 1234567
                               })
  end

  result.to_json
end

module VCAP::CloudController
  describe VCAP::CloudController::HM9000Client do
    let(:app0instances) { 1 }
    let(:app0) { AppFactory.make(instances: app0instances) }
    let(:app1) { AppFactory.make(instances: 1) }
    let(:app2) { AppFactory.make(instances: 1) }

    let(:hm9000_config) {
      {
        hm9000_api_host: "magic-bunnies.com",
        hm9000_api_port: 1812,
        hm9000_api_user: "MarkHammill",
        hm9000_api_password: "luke4ever",
        flapping_crash_count_threshold: 3,
      }
    }

    let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "RUNNING" }]) }
    let(:app_0_api_response_status) { 200 }
    let(:app_1_api_response) { generate_hm_api_response(app1, [{ index: 0, state: "CRASHED" }]) }
    let(:app_2_api_response) { generate_hm_api_response(app2, [{ index: 0, state: "RUNNING" }]) }

    subject(:hm9000_client) { VCAP::CloudController::HM9000Client.new(hm9000_config) }

    before do
      stub_request(:get, "MarkHammill:luke4ever@magic-bunnies.com:1812/app")
      .with(:query => { "app-guid" => app0.guid, "app-version" => app0.version })
      .to_return(body: app_0_api_response, status: app_0_api_response_status)

      stub_request(:get, "MarkHammill:luke4ever@magic-bunnies.com:1812/app")
      .with(:query => { "app-guid" => app1.guid, "app-version" => app1.version })
      .to_return(body: app_1_api_response)

      stub_request(:get, "MarkHammill:luke4ever@magic-bunnies.com:1812/app")
      .with(:query => { "app-guid" => app2.guid, "app-version" => app2.version })
      .to_return(body: app_2_api_response)
    end

    describe "healthy_instances" do
      context "single app" do
        context "with a single desired and running instance" do
          it "should return the correct number of healthy instances" do
            expect(hm9000_client.healthy_instances(app0)).to eq(1)
          end
        end

        context "when the request fails" do
          let(:app_0_api_response_status) { 404 }

          it "should return 0" do
            expect(hm9000_client.healthy_instances(app0)).to eq(0)
          end
        end

        context "with multiple desired instances" do
          let(:app0instances) { 3 }

          context "when all the desired instances are running" do
            let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "RUNNING" }, { index: 1, state: "RUNNING" }, { index: 2, state: "STARTING" }]) }

            it "should return the number of running instances" do
              expect(hm9000_client.healthy_instances(app0)).to eq(3)
            end
          end

          context "when only some of the desired instances are running" do
            let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "RUNNING" }, { index: 2, state: "STARTING" }]) }

            it "should return the number of running instances in the desired range" do
              expect(hm9000_client.healthy_instances(app0)).to eq(2)
            end
          end

          context "when there are extra instances outside of the desired range" do
            let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "RUNNING" }, { index: 2, state: "STARTING" }, { index: 3, state: "RUNNING" }]) }

            it "should only return the number of running instances in the desired range" do
              expect(hm9000_client.healthy_instances(app0)).to eq(2)
            end
          end

          context "when there are multiple instances running on the same index" do
            let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "RUNNING" }, { index: 2, state: "STARTING" }, { index: 2, state: "RUNNING" }]) }

            it "should only count one of the instances" do
              expect(hm9000_client.healthy_instances(app0)).to eq(2)
            end
          end

          context "when some of the desired instances are crashed" do
            let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "RUNNING" }, { index: 1, state: "CRASHED" }, { index: 2, state: "STARTING" }, { index: 2, state: "CRASHED" }]) }

            it "should not count the crashed instances" do
              expect(hm9000_client.healthy_instances(app0)).to eq(2)
            end
          end
        end
      end

      context "multiple apps" do
        it "should return a mapping of app-guid to # health instances" do
          expect(hm9000_client.healthy_instances([app0, app1, app2])).to eq({ app0.guid => 1, app1.guid => 0, app2.guid => 1 })
        end

        context "when one of the request fails" do
          let(:app_0_api_response_status) { 404 }

          it "should return 0 for that app, but be ok for the others" do
            expect(hm9000_client.healthy_instances([app0, app1, app2])).to eq({ app0.guid => 0, app1.guid => 0, app2.guid => 1 })
          end
        end
      end
    end

    describe "find_crashes" do
      let(:app_0_api_response) { generate_hm_api_response(app0, [{ index: 0, state: "CRASHED", instance_guid: "sham" }, { index: 1, state: "CRASHED", instance_guid: "wow" }, { index: 1, state: "RUNNING" }]) }

      context "when the request fails" do
        let(:app_0_api_response_status) { 404 }

        it "should return an empty array" do
          expect(hm9000_client.find_crashes(app0)).to eq([])
        end
      end

      context "when the request succeeds" do
        it "should return an array of all the crashed instances" do
          crashes = hm9000_client.find_crashes(app0)
          expect(crashes).to have(2).items
          expect(crashes).to include({ "instance" => "sham", "since" => 3.141 })
          expect(crashes).to include({ "instance" => "wow", "since" => 3.141 })
        end
      end
    end

    describe "find_flapping_indices" do
      let(:app_0_api_response) { generate_hm_api_response(app0, [], [{instance_index:0, crash_count:3}, {instance_index:1, crash_count:1}, {instance_index:2, crash_count:10}]) }

      context "when the request fails" do
        let(:app_0_api_response_status) { 404 }

        it "should return an empty array" do
          expect(hm9000_client.find_flapping_indices(app0)).to eq([])
        end
      end

      context "when the request succeeds" do
        it "should return an array of all the crashed instances" do
          flapping_indices = hm9000_client.find_flapping_indices(app0)
          expect(flapping_indices).to have(2).items
          expect(flapping_indices).to include({ "index" => 0, "since" => 1234567 })
          expect(flapping_indices).to include({ "index" => 2, "since" => 1234567 })
        end
      end
    end
  end
end
