module VCAP::CloudController
  RSpec.shared_examples 'filtering timestamps on creation' do |resource_class|
    context 'filtering timestamps on creation' do
      let!(:resource_1) { resource_class.make(guid: '1', created_at: '2020-05-26T18:47:01Z') }
      let!(:resource_2) { resource_class.make(guid: '2', created_at: '2020-05-26T18:47:02Z') }
      let!(:resource_3) { resource_class.make(guid: '3', created_at: '2020-05-26T18:47:03Z') }
      let!(:resource_4) { resource_class.make(guid: '4', created_at: '2020-05-26T18:47:04Z') }

      let(:filters) do
        { created_ats: { lt: resource_3.created_at.iso8601 } }
      end

      it 'delegates filtering to the base class' do
        expect(subject.all).to match_array([resource_1, resource_2])
      end
    end
  end

  RSpec.shared_examples 'filtering timestamps on update' do |resource_class|
    context 'filtering timestamps on update' do
      before do
        resource_class.plugin :timestamps, update_on_create: false
      end

      let!(:resource_1) { resource_class.make(guid: '1', updated_at: '2020-05-26T18:47:01Z') }
      let!(:resource_2) { resource_class.make(guid: '2', updated_at: '2020-05-26T18:47:02Z') }
      let!(:resource_3) { resource_class.make(guid: '3', updated_at: '2020-05-26T18:47:03Z') }
      let!(:resource_4) { resource_class.make(guid: '4', updated_at: '2020-05-26T18:47:04Z') }

      let(:filters) do
        { updated_ats: { lt: resource_3.updated_at.iso8601 } }
      end

      after do
        resource_class.plugin :timestamps, update_on_create: true
      end

      it 'delegates filtering to the base class' do
        expect(subject.all).to match_array([resource_1, resource_2])
      end
    end
  end
end
