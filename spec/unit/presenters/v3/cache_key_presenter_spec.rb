require 'spec_helper'
require 'presenters/v3/cache_key_presenter'

module VCAP::CloudController
  describe CacheKeyPresenter do
    context 'v2 app / v3 process' do
      it 'renders as app_guid/stack_name' do
        app = App.make

        key = CacheKeyPresenter.cache_key(guid: app.guid, stack_name: app.stack.name)

        expect(key).to eq("#{app.guid}/#{app.stack.name}")
      end
    end

    context 'v3 AppModel' do
      it 'renders as app_guid/stack_name' do
        app = AppModel.make
        stack_name = Stack.make.name
        key = CacheKeyPresenter.cache_key(guid: app.guid, stack_name: stack_name)
        expect(key).to eq("#{app.guid}/#{stack_name}")
      end
    end
  end
end
