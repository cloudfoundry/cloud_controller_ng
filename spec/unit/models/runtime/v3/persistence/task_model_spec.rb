require 'spec_helper'

module VCAP::CloudController
  describe TaskModel do
    describe 'validations' do
      let(:task) { TaskModel.make }
      let(:app) { AppModel.make }
      let(:droplet) { DropletModel.make(app_guid: app.guid) }

      describe 'name' do
        it 'should allow standard ascii characters' do
          task.name = "A -_- word 2!?()\'\"&+."
          expect {
            task.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          task.name = 'a \\ word'
          expect {
            task.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          task.name = '詩子¡'
          expect {
            task.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          task.name = "a \n word"
          expect {
            task.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          task.name = "a \e word"
          expect {
            task.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'state' do
        it 'can be RUNNING' do
          task.state = 'RUNNING'
          expect(task).to be_valid
        end

        it 'can not be something else' do
          task.state = 'SOMETHING ELSE'
          expect(task).to_not be_valid
        end
      end

      describe 'command' do
        it 'can be <= 4096 characters' do
          task.command = 'a' * 4096
          expect(task).to be_valid
        end

        it 'cannot be > 4096 characters' do
          task.command = 'a' * 4097
          expect(task).to_not be_valid
          expect(task.errors.full_messages).to include('command must be shorter than 4097 characters')
        end
      end

      describe 'environment_variables' do
        it 'validates them' do
          expect {
            AppModel.make(environment_variables: '')
          }.to raise_error(Sequel::ValidationFailed, /must be a hash/)
        end
      end

      describe 'presence' do
        it 'must have an app' do
          expect { TaskModel.make(name: 'name',
                                  droplet: droplet,
                                  app: nil,
                                  command: 'bundle exec rake db:migrate')
          }.to raise_error(Sequel::ValidationFailed, /app presence/)
        end

        it 'must have a command' do
          expect { TaskModel.make(name: 'name',
                                  droplet: droplet,
                                  app: app,
                                  command: nil)
          }.to raise_error(Sequel::ValidationFailed, /command presence/)
        end

        it 'must have a droplet' do
          expect { TaskModel.make(name: 'name',
                                  droplet: nil,
                                  app: app,
                                  command: 'bundle exec rake db:migrate')
          }.to raise_error(Sequel::ValidationFailed, /droplet presence/)
        end

        it 'must have a name' do
          expect { TaskModel.make(name: nil,
                                  droplet: droplet,
                                  app: app,
                                  command: 'bundle exec rake db:migrate')
          }.to raise_error(Sequel::ValidationFailed, /name presence/)
        end
      end
    end
  end
end
