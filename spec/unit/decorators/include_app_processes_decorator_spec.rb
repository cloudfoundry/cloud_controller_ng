require 'spec_helper'
require 'decorators/include_app_processes_decorator'

module VCAP::CloudController
  RSpec.describe IncludeAppProcessesDecorator do
    subject(:decorator) { IncludeAppProcessesDecorator }
    let(:app1) { AppModel.make }
    let(:app2) { AppModel.make }
    let(:apps) { [app1, app2, AppModel.make] }
    let!(:process1) { ProcessModel.make(app: app1) }
    let!(:process2) { ProcessModel.make(app: app1) }
    let!(:process3) { ProcessModel.make(app: app2) }

    it 'decorates the given hash with processes from apps' do
      wreathless_hash = { foo: 'bar' }
      hash = subject.decorate(wreathless_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:processes]).to match_array([Presenters::V3::ProcessPresenter.new(process1).to_hash,
                                                          Presenters::V3::ProcessPresenter.new(process2).to_hash,
                                                          Presenters::V3::ProcessPresenter.new(process3).to_hash])
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = { foo: 'bar', included: { monkeys: ['zach', 'greg'] } }
      hash = subject.decorate(wreathless_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:processes]).to match_array([Presenters::V3::ProcessPresenter.new(process1).to_hash,
                                                          Presenters::V3::ProcessPresenter.new(process2).to_hash,
                                                          Presenters::V3::ProcessPresenter.new(process3).to_hash])
      expect(hash[:included][:monkeys]).to match_array(['zach', 'greg'])
    end

    describe '.match?' do
      it 'matches include arrays containing "processes"' do
        expect(decorator.match?(['potato', 'processes', 'turnip'])).to be_truthy
      end

      it 'does not match other include arrays' do
        expect(decorator.match?(['potato', 'turnip'])).to be_falsey
      end
    end
  end
end
