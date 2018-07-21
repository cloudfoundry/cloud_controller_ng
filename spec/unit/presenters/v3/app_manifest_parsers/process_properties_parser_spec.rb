require 'spec_helper'

module VCAP::CloudController::Presenters::V3::AppManifestParsers
  RSpec.describe ProcessPropertiesParser do
    describe 'command' do

      let(:app) { VCAP::CloudController::AppModel.make() }

      context 'when a process does not have a user-specified command' do
        before do
          VCAP::CloudController::ProcessModelFactory.make(
            app: app,
          )
        end

        it 'should not include "command" in the output' do
          expect(subject.parse(app, nil, nil)[:processes].first)
            .not_to have_key('command')
        end
      end

      context 'when a process does have a user-specified command' do
        before do
          VCAP::CloudController::ProcessModelFactory.make(
            app: app,
            command: 'Do it now!'
          )
        end

        it 'should include the command in the output' do
          expect(subject.parse(app, nil, nil)[:processes].first['command']).to eq('Do it now!')
        end
      end
    end
  end

end
