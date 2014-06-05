require 'spec_helper'

module VCAP::CloudController
  describe SpaceSummariesController do
    let(:space) { Space.make }

    describe 'GET /v2/spaces/:id/summary' do
      let(:summary_response) { { 'the' => 'output i want to see as json'} }
      let(:space_summarizer) { double(:space_summarizer) }

      before do
        allow(SpaceSummarizer).to receive(:new).and_return space_summarizer
        allow(space_summarizer).to receive(:space_summary).and_return(summary_response)
      end

      def make_request
        get "/v2/spaces/#{space.guid}/summary", {}, admin_headers
      end

      it 'returns 200' do
        response = make_request
        expect(response.status).to eq(200)
      end

      it 'returns json from SpaceSummarizer' do
        response = make_request

        expect { JSON.parse(response.body) }.to_not raise_error
        response_body_as_hash = JSON.parse(response.body)
        expect(response_body_as_hash).to eq(summary_response)
      end

      it 'properly constructs SpaceSummarizer' do
        make_request

        expect(SpaceSummarizer).to have_received(:new) do |requested_space, instance_reporter|
          expect(requested_space.guid).to eq(space.guid)
          expect(instance_reporter).to be_kind_of(VCAP::CloudController::InstancesReporter::LegacyInstancesReporter)
        end
      end
    end
  end

  describe SpaceSummarizer do
    let(:space) { Space.make }
    let(:first_route) { Route.make(space: space) }
    let(:second_route) { Route.make(space: space) }
    let(:first_service) {  ManagedServiceInstance.make(space: space) }
    let(:second_service) {  ManagedServiceInstance.make(space: space) }
    let(:app) { AppFactory.make(space: space) }

    let(:instances_reporter) { double(:instances_reporter) }
    let(:running_instances) { 5 }

    subject { described_class.new(space, instances_reporter) }

    before do
      app.add_route(first_route)
      app.add_route(second_route)

      ServiceBinding.make(app: app, service_instance: first_service)
      ServiceBinding.make(app: app, service_instance: second_service)

      allow(instances_reporter).to receive(:number_of_starting_and_running_instances_for_app).
                                     and_return(running_instances)
    end

    describe '#app_summary' do
      let(:app_summary) { subject.app_summary}

      it 'is an array' do
        expect(app_summary).to be_kind_of(Array)
      end

      context 'when the space has multiple apps' do
        before do
          AppFactory.make(space: space)
          AppFactory.make(space: space)
        end

        it 'has an equal number of summaries' do
          expect(app_summary.length).to eq(3)
        end
      end

      describe 'summary format' do
        let(:summary) { app_summary.first }

        it 'includes the app.to_hash' do
          expect(summary).to include(app.to_hash)
        end

        it 'includes the app guid' do
          expect(summary).to include(guid: app.guid)
        end

        it 'includes route summary information' do
          expect(summary).to include(urls: [first_route.fqdn, second_route.fqdn])
          expect(summary).to include(routes: [{
                                                guid: first_route.guid,
                                                host: first_route.host,
                                                domain: {
                                                  guid: first_route.domain.guid,
                                                  name: first_route.domain.name
                                                }
                                              }, {
                                                guid: second_route.guid,
                                                host: second_route.host,
                                                domain: {
                                                  guid: second_route.domain.guid,
                                                  name: second_route.domain.name
                                                }
                                              }]
                             )
        end

        it 'includes service summary information' do
          expect(summary).to include(service_count: 2)
          expect(summary).to include(service_names: [first_service.name, second_service.name])
        end

        it 'includes instance summary information' do
          expect(summary).to include(running_instances: running_instances)
          expect(instances_reporter).to have_received(:number_of_starting_and_running_instances_for_app) do |requested_app|
            expect(requested_app.guid).to eq(app.guid)
          end
        end
      end
    end

    describe '#services_summary' do
      let(:summary) { subject.services_summary }

      it 'returns an array of summaries' do
        expect(summary).to be_kind_of(Array)
        expect(summary.length).to eq(2)
      end

      it 'the summaries are instance.as_summary_json' do
        expect(summary).to include({
                                     'guid' => first_service.guid,
                                     'name' => first_service.name,
                                     'bound_app_count' => 1,
                                     'dashboard_url' => first_service.dashboard_url,
                                     'service_plan' => {
                                       'guid' => first_service.service_plan.guid,
                                       'name' => first_service.service_plan.name,
                                       'service' => {
                                         'guid' => first_service.service_plan.service.guid,
                                         'label' => first_service.service_plan.service.label,
                                         'provider' => first_service.service_plan.service.provider,
                                         'version' => first_service.service_plan.service.version,
                                       }
                                     }
                                   })
      end
    end

    describe '#space_summary' do
      let(:space_summary) { subject.space_summary }

      it 'includes space guid' do
        expect(space_summary[:guid]).to eq(space.guid)
      end

      it 'includes space name' do
        expect(space_summary[:name]).to eq(space.name)
      end

      it 'includes apps summary' do
        expect(space_summary[:apps]).to eq(subject.app_summary)
      end

      it 'includes services summary' do
        expect(space_summary[:services]).to eq(subject.services_summary)
      end
    end
  end
end
