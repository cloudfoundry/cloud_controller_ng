require 'spec_helper'
require 'presenters/v3/shared_spaces_usage_summary_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SharedSpacesUsageSummaryPresenter do
    let(:presenter) { described_class.new(instance) }
    let(:result) { presenter.to_hash.deep_symbolize_keys }

    let(:space) { VCAP::CloudController::Space.make }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }

    let(:space_1) { VCAP::CloudController::Space.make }
    let(:space_2) { VCAP::CloudController::Space.make }
    let(:space_3) { VCAP::CloudController::Space.make }

    def create_bindings(instance, space:, count:)
      (1..count).each do
        VCAP::CloudController::ServiceBinding.make(
          app: VCAP::CloudController::AppModel.make(space: space),
          service_instance: instance
        )
      end
    end

    before do
      instance.add_shared_space(space_1)
      instance.add_shared_space(space_2)
      instance.add_shared_space(space_3)

      create_bindings(instance, space: space, count: 2)
      create_bindings(instance, space: space_1, count: 3)
      create_bindings(instance, space: space_2, count: 1)
    end

    it 'presents the usage summary' do
      expect(result).to eq({
        usage_summary: [{
          space: { guid: space_1.guid },
          bound_app_count: 3
        }, {
          space: { guid: space_2.guid },
          bound_app_count: 1
        }, {
          space: { guid: space_3.guid },
          bound_app_count: 0
        }],
        links: {
          self: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces/usage_summary" },
          shared_spaces: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces" },
          service_instance: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}" }
        }
      })
    end

    context 'when there are no shared spaces' do
      let(:another_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
      let(:presenter) { described_class.new(another_instance) }

      it 'presents an empty usage summary' do
        expect(result).to eq({
          usage_summary: [],
          links: {
            self: { href: "#{link_prefix}/v3/service_instances/#{another_instance.guid}/relationships/shared_spaces/usage_summary" },
            shared_spaces: { href: "#{link_prefix}/v3/service_instances/#{another_instance.guid}/relationships/shared_spaces" },
            service_instance: { href: "#{link_prefix}/v3/service_instances/#{another_instance.guid}" }
          }
        })
      end
    end
  end
end
