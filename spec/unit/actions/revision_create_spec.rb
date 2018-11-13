require 'spec_helper'
require 'actions/revision_create'

module VCAP::CloudController
  RSpec.describe RevisionCreate do
    subject(:revision_create) { RevisionCreate }
    let(:app) { AppModel.make }

    describe '.create' do
      it 'creates a revision for the app' do
        expect {
          subject.create(app)
        }.to change { RevisionModel.where(app: app).count }.by(1)
      end

      context 'when there are multiple revisions for an app' do
        it 'increments the version by 1' do
          subject.create(app)
          subject.create(app)
          subject.create(app)

          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([1, 2, 3])
        end

        it 'rolls over to version 1 when we pass version 9999' do
          RevisionModel.make(app: app, version: 1)
          RevisionModel.make(app: app, version: 2)
          # ...
          RevisionModel.make(app: app, version: 9998)
          RevisionModel.make(app: app, version: 9999)

          subject.create(app)
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([2, 9998, 9999, 1])
        end

        it 'replaces any existing revisions after rolling over' do
          RevisionModel.make(app: app, version: 1)
          RevisionModel.make(app: app, version: 2)
          # ...
          RevisionModel.make(app: app, version: 9998)
          RevisionModel.make(app: app, version: 9999)

          subject.create(app)
          subject.create(app)
          subject.create(app)
          expect(RevisionModel.order_by(:created_at).map(&:version)).to eq([9998, 9999, 1, 2, 3])
        end
      end
    end
  end
end
