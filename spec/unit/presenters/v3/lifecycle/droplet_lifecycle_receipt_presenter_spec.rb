require 'spec_helper'
require_relative 'droplet_lifecycle_receipt_presenter_shared'

module VCAP
  module CloudController
    describe DropletLifecycleReceiptPresenter do
      subject(:presenter) { DropletLifecycleReceiptPresenter.new }

      it_behaves_like 'a droplet lifecycle receipt presenter'

      describe '#result' do
        let(:droplet) { DropletModel.make(buildpack_receipt_buildpack: 'receipt_buildpack', buildpack_receipt_stack_name: 'receipt_stack') }

        it 'returns a hash with receipt details' do
          expect(presenter.result(droplet)).to eq({
            buildpack: 'receipt_buildpack',
            stack:     'receipt_stack',
          })
        end
      end

      describe '#links' do
        context 'when the buildpack is an admin buildpack' do
          let(:droplet) { DropletModel.make(buildpack_receipt_buildpack_guid: 'some-guid') }

          it 'links to the buildpack' do
            expect(presenter.links(droplet)).to eq({
              buildpack: {
                href: '/v2/buildpacks/some-guid'
              }
            })
          end
        end

        context 'when the buildpack is not an admin buildpack' do
          let(:droplet) { DropletModel.make }

          it 'links to nil' do
            expect(presenter.links(droplet)).to eq({ buildpack: nil })
          end
        end
      end
    end
  end
end
