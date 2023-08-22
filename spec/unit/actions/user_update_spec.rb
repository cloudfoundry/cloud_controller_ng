require 'spec_helper'
require 'actions/user_update'

module VCAP::CloudController
  RSpec.describe UserUpdate do
    subject(:user_update) { UserUpdate.new }

    describe '#update' do
      let(:old_labels) do
        {
          fruit: 'pears',
          truck: 'hino'
        }
      end
      let(:old_annotations) do
        {
          potato: 'celandine',
          beet: 'formanova',
        }
      end
      let(:new_labels) do
        {
          release: 'stable',
          'seriouseats.com/potato' => 'mashed',
          fruit: 'strawberries',
        }
      end
      let(:new_annotations) do
        {
          potato: 'idaho',
        }
      end
      let(:body) do
        {
          metadata: {
            labels: new_labels,
            annotations: new_annotations,
          },
        }
      end

      let(:user) { User.make }
      let(:message) { UserUpdateMessage.new(body) }

      context 'when there is no current metadata' do
        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            user_update.update(user: user, message: message)
            user.reload
            expect(user.labels.size).to eq(0)
            expect(user.annotations.size).to eq(0)
          end
        end

        context 'when metadata is specified' do
          it 'updates the user metadata' do
            expect(message).to be_valid
            user_update.update(user: user, message: message)

            user.reload
            expect(user).to have_labels(
              { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' },
                { prefix: nil, key_name: 'fruit', value: 'strawberries' },
                { prefix: nil, key_name: 'release', value: 'stable' },
              )
            expect(user).to have_annotations(
              { key_name: 'potato', value: 'idaho' }
              )
          end
        end
      end

      context 'when the user has existing metadata' do
        before do
          VCAP::CloudController::LabelsUpdate.update(user, old_labels, VCAP::CloudController::UserLabelModel)
          VCAP::CloudController::AnnotationsUpdate.update(user, old_annotations, VCAP::CloudController::UserAnnotationModel)
        end

        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            user_update.update(user: user, message: message)
            user.reload
            expect(user).to have_labels(
              { prefix: nil, key_name: 'fruit', value: 'pears' },
                { prefix: nil, key_name: 'truck', value: 'hino' },
              )
            expect(user).to have_annotations(
              { key_name: 'potato', value: 'celandine' },
                { key_name: 'beet', value: 'formanova' },
              )
          end
        end

        context 'when metadata is specified' do
          let(:body) do
            {
              metadata: {
                labels: new_labels.merge(fruit: nil, newstuff: 'here'),
                annotations: new_annotations.merge(beet: nil, asparagus: 'crunchy'),
              },
            }
          end

          it 'updates some, deletes nils, leaves unspecified fields alone' do
            expect(message).to be_valid
            user_update.update(user: user, message: message)
            user.reload
            expect(user).to have_labels(
              { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' },
                { prefix: nil, key_name: 'release', value: 'stable' },
                { prefix: nil, key_name: 'truck', value: 'hino' },
                { prefix: nil, key_name: 'newstuff', value: 'here' },
              )
            expect(user).to have_annotations(
              { key_name: 'potato', value: 'idaho' },
                { key_name: 'asparagus', value: 'crunchy' },
              )
          end
        end
      end
    end
  end
end
