require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CrashesController do
    describe "GET /v2/apps/:id/crashes" do
      before :each do
        @app = AppFactory.make
        @user = make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context "as a developer" do
        let(:instances_reporter) { double(:instances_reporter) }
        let(:crashed_instances) do
          [
            {:instance => "instance_1", :since => 1},
            {:instance => "instance_2", :since => 1},
          ]
        end

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:instances_reporter).and_return(instances_reporter)
          allow(instances_reporter).to receive(:crashed_instances_for_app).and_return(crashed_instances)
        end

        it "returns the crashed instances" do
          expected = [
            {"instance" => "instance_1", "since" => 1},
            {"instance" => "instance_2", "since" => 1},
          ]

          get("/v2/apps/#{@app.guid}/crashes", {}, headers_for(@developer))

          expect(last_response.status).to eq(200)
          expect(MultiJson.load(last_response.body)).to eq(expected)
          expect(instances_reporter).to have_received(:crashed_instances_for_app).with(
                                          satisfy { |requested_app| requested_app.guid == @app.guid })
        end
      end

      context "as a user" do
        it "returns 403" do
          get("/v2/apps/#{@app.guid}/crashes",
              {},
              headers_for(@user))

          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
