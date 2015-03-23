# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe AppModel do
    let(:app_model) { AppModel.make }
    let(:space) { Space.find(guid: app_model.space_guid) }

    describe '.user_visible' do
      it 'shows the developer apps' do
        developer = User.make
        space.organization.add_user developer
        space.add_developer developer
        expect(AppModel.user_visible(developer)).to include(app_model)
      end

      it 'shows the space manager apps' do
        space_manager = User.make
        space.organization.add_user space_manager
        space.add_manager space_manager

        expect(AppModel.user_visible(space_manager)).to include(app_model)
      end

      it 'shows the auditor apps' do
        auditor = User.make
        space.organization.add_user auditor
        space.add_auditor auditor

        expect(AppModel.user_visible(auditor)).to include(app_model)
      end

      it 'shows the org manager apps' do
        org_manager = User.make
        space.organization.add_manager org_manager

        expect(AppModel.user_visible(org_manager)).to include(app_model)
      end

      it 'hides everything from a regular user' do
        evil_hacker = User.make
        expect(AppModel.user_visible(evil_hacker)).to_not include(app_model)
      end
    end

    describe 'validations' do
      describe 'name' do
        let(:space_guid) { space.guid }
        let(:app) { AppModel.make }

        it 'uniqueness is case insensitive' do
          AppModel.make(name: 'lowercase', space_guid: space_guid)

          expect {
            AppModel.make(name: 'lowerCase', space_guid: space_guid)
          }.to raise_error(Sequel::ValidationFailed, /space_guid and name/)
        end

        it 'should allow standard ascii characters' do
          app.name = "A -_- word 2!?()\'\"&+."
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          app.name = 'a \\ word'
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          app.name = '防御力¡'
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          app.name = "a \n word"
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          app.name = "a \e word"
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'name is unique within a space' do
        it 'name can be reused in different spaces' do
          name = 'zach'

          space1 = Space.make
          space2 = Space.make

          AppModel.make(name: name, space_guid: space1.guid)
          expect {
            AppModel.make(name: name, space_guid: space2.guid)
          }.not_to raise_error
        end

        it 'name is unique in the same space' do
          name = 'zach'

          space = Space.make

          AppModel.make(name: name, space_guid: space.guid)

          expect {
            AppModel.make(name: name, space_guid: space.guid)
          }.to raise_error(Sequel::ValidationFailed, /space_guid and name/)
        end
      end

      describe 'environment_variables' do
        it 'validates that the input is a hash' do
          expect {
            AppModel.make(environment_variables: '')
          }.to raise_error(Sequel::ValidationFailed, /must be a JSON hash/)

          expect {
            AppModel.make(environment_variables: 3)
          }.to raise_error(Sequel::ValidationFailed, /must be a JSON hash/)
        end

        it 'does not allow variables that start with CF_' do
          expect {
            AppModel.make(environment_variables: { CF_POTATO: 'muy bueno' })
          }.to raise_error(Sequel::ValidationFailed, /cannot start with CF_/)
        end

        it 'does not allow variables that start with cf_' do
          expect {
            AppModel.make(environment_variables: { cf_potato: 'muy bueno' })
          }.to raise_error(Sequel::ValidationFailed, /cannot start with CF_/)
        end

        it 'does not allow variables that start with VCAP_' do
          expect {
            AppModel.make(environment_variables: { VCAP_BANANA: 'no bueno' })
          }.to raise_error(Sequel::ValidationFailed, /cannot start with VCAP_/)
        end

        it 'does not allow variables that start with vcap_' do
          expect {
            AppModel.make(environment_variables: { vcap_banana: 'no bueno' })
          }.to raise_error(Sequel::ValidationFailed, /cannot start with VCAP_/)
        end

        it 'does not allow PORT' do
          expect {
            AppModel.make(environment_variables: { PORT: 'el martes nos ponemos camisetas naranjas' })
          }.to raise_error(Sequel::ValidationFailed, /cannot set PORT/)
        end
      end
    end
  end
end
