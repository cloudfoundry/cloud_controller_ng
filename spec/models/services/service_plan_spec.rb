require "spec_helper"

module VCAP::CloudController
  describe Models::ServicePlan, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :free, :description, :service],
      :unique_attributes => [ [:service, :name] ],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :service => {
          :delete_ok => true,
          :create_for => lambda { |service_plan| Models::Service.make },
        },
      },
      :one_to_zero_or_more => {
        :service_instances => lambda { |service_plan| Models::ManagedServiceInstance.make }
      },
    }

    describe '#save' do
      context 'on create' do
        context 'when no unique_id is set' do
          let(:attrs) { {unique_id: nil} }

          it 'generates guid for the unique_id' do
            plan = Models::ServicePlan.make(attrs)
            expect(plan.unique_id).to be_a_guid
          end
        end

        context 'when a unique_id is set' do
          let(:attrs) { {unique_id: Sham.guid} }

          it 'persists the given unique_id' do
            plan = Models::ServicePlan.make(attrs)
            expect(plan.unique_id).to eq(attrs[:unique_id])
          end
        end
      end

      context 'on update' do
        let(:plan) { Models::ServicePlan.make }

        context 'when the unique_id is unset' do
          before { plan.unique_id = nil }

          it 'does not generate a unique_id' do
            expect {
              plan.save rescue nil
            }.to_not change(plan, :unique_id)
          end

          it 'raises a validation error' do
            expect {
              plan.save
            }.to raise_error(Sequel::ValidationFailed)
          end
        end
      end
    end

    describe "#destroy" do
      let(:service_plan) { Models::ServicePlan.make }

      it "destroys all service instances" do
        service_instance = Models::ManagedServiceInstance.make(:service_plan => service_plan)
        expect { service_plan.destroy }.to change {
          Models::ManagedServiceInstance.where(:id => service_instance.id).any?
        }.to(false)
      end

      it "destroys all service plan visibilities" do
        service_plan_visibility = Models::ServicePlanVisibility.make(:service_plan => service_plan)
        expect { service_plan.destroy }.to change {
          Models::ServicePlanVisibility.where(:id => service_plan_visibility.id).any?
        }.to(false)
      end
    end

    describe ".organization_visible" do
      it "returns plans that are visible to the organization" do
        hidden_private_plan = Models::ServicePlan.make(public: false)
        visible_public_plan = Models::ServicePlan.make(public: true)
        visible_private_plan = Models::ServicePlan.make(public: false)

        organization = Models::Organization.make
        Models::ServicePlanVisibility.make(organization: organization, service_plan: visible_private_plan)

        visible = Models::ServicePlan.organization_visible(organization).all
        visible.should include(visible_public_plan)
        visible.should include(visible_private_plan)
        visible.should_not include(hidden_private_plan)
      end
    end

    describe "serialization" do
      let(:service_plan) {
        Models::ServicePlan.new_from_hash(extra: "extra", public: false, unique_id: "unique-id")
      }

      it "allows mass assignment of extra" do
         service_plan.extra.should == "extra"
      end

      it "allows export of extra"  do
         Yajl::Parser.parse(service_plan.to_json)["extra"].should == "extra"
      end

      it "allows massignment of public" do
        service_plan.public.should == false
      end

      it "allows mass assignment of unique_id" do
        service_plan.unique_id.should == "unique-id"
      end
    end

    describe "#bindable?" do
      let(:service_plan) { Models::ServicePlan.make(service: service) }

      context "when the service is bindable" do
        let(:service) { Models::Service.make(bindable: true) }
        specify { service_plan.should be_bindable }
      end

      context "when the service is unbindable" do
        let(:service) { Models::Service.make(bindable: false) }
        specify { service_plan.should_not be_bindable }
      end
    end
  end
end
