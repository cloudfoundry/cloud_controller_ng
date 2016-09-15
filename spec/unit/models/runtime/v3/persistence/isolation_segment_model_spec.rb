require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IsolationSegmentModel do
    let(:isolation_segment_model) { IsolationSegmentModel.make }

    describe 'associations' do
      describe 'spaces' do
        let(:space_1) { Space.make }
        let(:space_2) { Space.make }

        it 'one isolation_segment can reference a single spaces' do
          isolation_segment_model.add_space(space_1)

          expect(isolation_segment_model.spaces).to include(space_1)
          expect(space_1.isolation_segment_model).to eq isolation_segment_model
        end

        it 'one isolation_segment can reference multiple spaces' do
          isolation_segment_model.add_space(space_1)
          isolation_segment_model.add_space(space_2)

          expect(isolation_segment_model.spaces).to include(space_1, space_2)
          expect(space_1.isolation_segment_model).to eq isolation_segment_model
          expect(space_2.isolation_segment_model).to eq isolation_segment_model
        end

        it 'multiple isolation_segments cannot reference the same space' do
          isolation_segment_model_2 = IsolationSegmentModel.make

          isolation_segment_model.add_space(space_1)
          isolation_segment_model_2.add_space(space_1)

          expect(isolation_segment_model.spaces).to be_empty
          expect(isolation_segment_model_2.spaces).to include(space_1)
        end

        context 'removing spaces from isolation segments' do
          it 'properly removes the associations' do
            isolation_segment_model.add_space(space_1)
            space_1.reload

            isolation_segment_model.remove_space(space_1)
            isolation_segment_model.reload

            expect(isolation_segment_model.spaces).to be_empty
            expect(space_1.isolation_segment_model).to be_nil
          end
        end
      end

      describe 'organizations' do
        let(:org) { Organization.make }
        let(:org_1) { Organization.make }
        let(:org_2) { Organization.make }

        it 'allows one isolation_segment to reference a single organization' do
          isolation_segment_model.add_organization(org_1)

          expect(isolation_segment_model.organizations).to include(org_1)
          expect(org_1.isolation_segment_models).to include(isolation_segment_model)
        end

        it 'allows one isolation segment to be referenced by multiple organizations' do
          isolation_segment_model.add_organization(org_1)
          isolation_segment_model.add_organization(org_2)

          expect(isolation_segment_model.organizations).to include(org_1, org_2)
          expect(org_1.isolation_segment_models).to include(isolation_segment_model)
          expect(org_2.isolation_segment_models).to include(isolation_segment_model)
        end

        it 'allows multiple isolation segments to be applied to one organization' do
          isolation_segment_model_2 = IsolationSegmentModel.make

          isolation_segment_model.add_organization(org_1)
          isolation_segment_model_2.add_organization(org_1)

          expect(isolation_segment_model.organizations).to include(org_1)
          expect(isolation_segment_model_2.organizations).to include(org_1)
          expect(org_1.isolation_segment_models).to include(isolation_segment_model, isolation_segment_model_2)
        end

        context 'when adding isolation segments to the allowed list' do
          it 'adds a segment to the allowed list' do
            isolation_segment_model.add_organization(org)
            expect(org.isolation_segment_models).to include(isolation_segment_model)
          end

          it 'sets the first isolation segment added as the default' do
            isolation_segment_model.add_organization(org)
            expect(org.isolation_segment_model).to eq(isolation_segment_model)
          end

          context 'and one isolation segment is in allowed list' do
            before do
              isolation_segment_model.add_organization(org)
            end

            it 'can be removed' do
              isolation_segment_model.remove_organization(org)

              expect(isolation_segment_model.organizations).to be_empty
              expect(org.isolation_segment_models).to be_empty
              expect(org.isolation_segment_model).to be_nil
            end

            it 'only removes the correct org' do
              isolation_segment_model.remove_organization(org_1)

              expect(isolation_segment_model.organizations).to eq([org])
              expect(org.isolation_segment_models).to eq([isolation_segment_model])
              expect(org.isolation_segment_model).to eq(isolation_segment_model)
            end

            context 'and the isolation segment has been added to a space in the org' do
              let!(:space) { Space.make(organization: org, isolation_segment_guid: isolation_segment_model.guid) }

              context 'and we remove the isolation segment' do
                it 'does not allow the isolation segment to be deleted' do
                  expect {
                    isolation_segment_model.remove_organization(org)
                  }.to raise_error(CloudController::Errors::ApiError)

                  expect(isolation_segment_model.organizations).to eq([org])
                  expect(org.isolation_segment_models).to eq([isolation_segment_model])
                  expect(org.isolation_segment_model).to eq(isolation_segment_model)
                end
              end
            end
          end

          context 'and multiple isolation segments are in allowed list' do
            let(:isolation_segment_model_2) { IsolationSegmentModel.make }

            before do
              isolation_segment_model.add_organization(org)
              isolation_segment_model_2.add_organization(org)
            end

            it 'cannot remove the isolation segment that has been set as the default' do
              expect(org.isolation_segment_model).to eq(isolation_segment_model)
              expect {
                isolation_segment_model.remove_organization(org)
              }.to raise_error(CloudController::Errors::ApiError)
            end

            it 'can remove an isolation segment that is not the default' do
              expect(org.isolation_segment_model).to_not eq(isolation_segment_model_2)
              isolation_segment_model_2.remove_organization(org)
              expect(org.isolation_segment_models).to eq([isolation_segment_model])
            end

            context 'and an isolation segment that is not the default has been associated with a space' do
              let(:space) { Space.make(organization: org) }

              before do
                expect(org.isolation_segment_model).to_not eq(isolation_segment_model_2)
                space.isolation_segment_model = isolation_segment_model_2
                space.save
              end

              it 'does not allow the isolation segment to be deleted' do
                expect {
                  isolation_segment_model_2.remove_organization(org)
                }.to raise_error(CloudController::Errors::ApiError)
              end
            end
          end
        end

        context 'when setting the default isolation segment' do
          it 'must be in the allowed list' do
          end

          it 'can be updated' do
          end
        end
    end
  end

    describe 'validations' do
      it 'requires a name' do
        expect {
          IsolationSegmentModel.make(name: nil)
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names can only contain non-blank unicode characters')
      end

      it 'requires a non blank name' do
        expect {
          IsolationSegmentModel.make(name: '')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names can only contain non-blank unicode characters')
      end

      it 'requires a unique name' do
        IsolationSegmentModel.make(name: 'segment1')

        expect {
          IsolationSegmentModel.make(name: 'segment1')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names are case insensitive and must be unique')
      end

      it 'uniqueness is case insensitive' do
        IsolationSegmentModel.make(name: 'lowercase')

        expect {
          IsolationSegmentModel.make(name: 'lowerCase')
        }.to raise_error(Sequel::ValidationFailed, 'isolation segment names are case insensitive and must be unique')
      end

      it 'should allow standard ascii characters' do
        expect {
          IsolationSegmentModel.make(name: "A -_- word 2!?()\'\"&+.")
        }.to_not raise_error
      end

      it 'should allow backslash characters' do
        expect {
          IsolationSegmentModel.make(name: 'a \\ word')
        }.to_not raise_error
      end

      it 'should allow unicode characters' do
        expect {
          IsolationSegmentModel.make(name: '防御力¡')
        }.to_not raise_error
      end

      it 'should not allow newline characters' do
        expect {
          IsolationSegmentModel.make(name: "a \n word")
        }.to raise_error(Sequel::ValidationFailed)
      end

      it 'should not allow escape characters' do
        expect {
          IsolationSegmentModel.make(name: "a \e word")
        }.to raise_error(Sequel::ValidationFailed)
      end
    end

    describe '#before_destroy' do
      let(:org) { Organization.make }

      it 'raises an error if still assigned to any orgs' do
        isolation_segment_model.add_organization(org)
        expect { isolation_segment_model.destroy }.to raise_error(CloudController::Errors::ApiError, /Please delete the Organization associations for your Isolation Segment/)
      end

      it 'raises an error if there are still spaces associated' do
        Space.make(isolation_segment_guid: isolation_segment_model.guid)
        expect { isolation_segment_model.destroy }.to raise_error(CloudController::Errors::ApiError, /Please delete the space/)
      end
    end
  end
end
