require 'spec_helper'

RSpec.describe 'populate VIPS for preexisting routes', isolation: :truncation do
  def run_migration
    Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
  end

  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20181129180059_populate_vips.rb'),
      tmp_migrations_dir,
    )
  end

  context 'when some internal routes exist before the migration' do
    let(:internal_domain) { VCAP::CloudController::SharedDomain.make(name: 'apps.internal', internal: true) }
    let(:external_domain) { VCAP::CloudController::SharedDomain.make(name: 'apps.external', internal: false) }
    # these are set to silly values so we know the migration works
    let!(:internal_route_1) { VCAP::CloudController::Route.make(host: 'meow', domain: internal_domain, vip_offset: 123) }
    let!(:internal_route_2) { VCAP::CloudController::Route.make(host: 'woof', domain: internal_domain, vip_offset: 456) }
    let!(:internal_route_3) { VCAP::CloudController::Route.make(host: 'quack', domain: internal_domain, vip_offset: 789) }

    let!(:external_route) { VCAP::CloudController::Route.make(host: 'moo', domain: external_domain, vip_offset: nil) }

    it 'populates the routes vip_offset for internal routes only' do
      run_migration

      expect(internal_route_1.reload.vip_offset).to eq(1)
      expect(internal_route_2.reload.vip_offset).to eq(2)
      expect(internal_route_3.reload.vip_offset).to eq(3)

      expect(external_route.reload.vip_offset).to be_nil
    end
  end
end
