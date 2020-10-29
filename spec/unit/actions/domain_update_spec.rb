require 'spec_helper'
require 'actions/domain_update'

module VCAP::CloudController
  RSpec.describe DomainUpdate do
    subject(:domain_update) { DomainUpdate.new }

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

      let(:domain) { SharedDomain.make }
      let(:message) { DomainUpdateMessage.new(body.merge({ guid: domain.guid })) }

      context 'when there is no current metadata' do
        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            domain_update.update(domain: domain, message: message)
            domain.reload
            expect(domain.labels.size).to eq(0)
            expect(domain.annotations.size).to eq(0)
          end
        end

        context 'when metadata is specified' do
          it 'updates the domain metadata' do
            expect(message).to be_valid
            domain_update.update(domain: domain, message: message)

            domain.reload
            expect(domain).to have_labels(
              { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
                { prefix: nil, key: 'fruit', value: 'strawberries' },
                { prefix: nil, key: 'release', value: 'stable' },
              )
            expect(domain).to have_annotations(
              { key: 'potato', value: 'idaho' }
            )
          end
        end
      end

      context 'when the domain has existing metadata' do
        before do
          VCAP::CloudController::LabelsUpdate.update(domain, old_labels, VCAP::CloudController::DomainLabelModel)
          VCAP::CloudController::AnnotationsUpdate.update(domain, old_annotations, VCAP::CloudController::DomainAnnotationModel)
        end

        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            domain_update.update(domain: domain, message: message)
            domain.reload
            expect(domain).to have_labels(
              { prefix: nil, key: 'fruit', value: 'pears' },
                { prefix: nil, key: 'truck', value: 'hino' },
              )
            expect(domain).to have_annotations(
              { key: 'potato', value: 'celandine' },
                { key: 'beet', value: 'formanova' },
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
            domain_update.update(domain: domain, message: message)
            domain.reload
            expect(domain).to have_labels(
              { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
                { prefix: nil, key: 'release', value: 'stable' },
                { prefix: nil, key: 'truck', value: 'hino' },
                { prefix: nil, key: 'newstuff', value: 'here' },
              )
            expect(domain).to have_annotations(
              { key: 'potato', value: 'idaho' },
                { key: 'asparagus', value: 'crunchy' },
              )
          end
        end
      end
    end
  end
end
