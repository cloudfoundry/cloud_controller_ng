require 'spec_helper'
require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUnassign do
    let(:assigner) { IsolationSegmentAssign.new }
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:org) { Organization.make }
    let(:org2) { Organization.make }

    it 'sorts the organizations passed in for unassignment' do
      org.update(guid: 'b')
      org2.update(guid: 'a')

      org.reload
      org2.reload

      expect(isolation_segment_model).to receive(:remove_organization).with(org2).ordered
      expect(isolation_segment_model).to receive(:remove_organization).with(org).ordered
      subject.unassign(isolation_segment_model, [org, org2])
    end

    context 'when an Isolation Segment is not assigned to any Orgs' do
      it 'is idempotent' do
        subject.unassign(isolation_segment_model, [org])
        expect(org.isolation_segment_models).to eq([])
      end
    end

    context 'when Organizations have been assigned to an Isolation Segment' do
      before do
        assigner.assign(isolation_segment_model, [org, org2])
      end

      it 'can remove a single org form the Isolation Segment' do
        subject.unassign(isolation_segment_model, [org])
        expect(isolation_segment_model.organizations).to eq([org2])
      end

      it 'can remove multiple Organizations from the Isolation Segment' do
        subject.unassign(isolation_segment_model, [org, org2])
        expect(isolation_segment_model.organizations).to eq([])
      end

      context 'and the Organization has the Isolation segment as the default' do
        before do
          org.update(default_isolation_segment_model: isolation_segment_model)
        end

        it 'can remove the Organization from the isolation segment' do
          subject.unassign(isolation_segment_model, [org])
          expect(isolation_segment_model.organizations).to eq([org2])
        end

        it "removes the organization's default Isolation Segment" do
          subject.unassign(isolation_segment_model, [org])
          expect(org.default_isolation_segment_model).to be_nil
        end

        context 'and the Organization has a space assigned' do
          let!(:space) { Space.make(organization: org) }

          it 'allows the isolation segment to remove the organization' do
            subject.unassign(isolation_segment_model, [org])
            expect(isolation_segment_model.organizations).to eq([org2])
          end

          context 'and the space is assigned the Isolation Segment' do
            before do
              space.update(isolation_segment_model: isolation_segment_model)
            end

            it 'does not remove the org from the Isolation Segment' do
              expect {
                subject.unassign(isolation_segment_model, [org])
              }.to raise_error IsolationSegmentUnassign::IsolationSegmentUnassignError, 'Please delete the Space associations for your Isolation Segment.'

              expect(isolation_segment_model.organizations).to include(org, org2)
            end
          end

          context 'and the space has no assigned isolation segment' do
            context 'and the space has an app' do
              before do
                AppModel.make(space: space)
              end

              it 'does not remove the org from the Isolation Segment' do
                expect {
                  subject.unassign(isolation_segment_model, [org])
                }.to raise_error CloudController::Errors::ApiError, /Removing default Isolation Segment could not be completed/

                expect(isolation_segment_model.organizations).to include(org, org2)
              end
            end
          end
        end
      end

      context 'and the Organaization has a space assigned' do
        let!(:space) { Space.make(organization: org) }

        it 'allows the isolation segment to remove the organization' do
          subject.unassign(isolation_segment_model, [org])
          expect(isolation_segment_model.organizations).to eq([org2])
        end

        context 'and the space is assigned the Isolation Segment' do
          before do
            space.update(isolation_segment_model: isolation_segment_model)
          end

          it 'does not remove the org from the Isolation Segment' do
            expect {
              subject.unassign(isolation_segment_model, [org])
            }.to raise_error IsolationSegmentUnassign::IsolationSegmentUnassignError, 'Please delete the Space associations for your Isolation Segment.'

            expect(isolation_segment_model.organizations).to include(org, org2)
          end
        end

        context 'and the space has an app' do
          before do
            AppModel.make(space: space)
          end

          it 'removes the Organization form the Isolation Segment' do
            subject.unassign(isolation_segment_model, [org])
            expect(isolation_segment_model.organizations).to include(org2)
          end
        end
      end
    end
  end
end
