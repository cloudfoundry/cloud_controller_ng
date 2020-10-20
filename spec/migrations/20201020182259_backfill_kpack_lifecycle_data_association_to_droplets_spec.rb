require 'spec_helper'

RSpec.describe 'convert "docker" droplets with a "kpack" build to "kpack" droplets', isolation: :truncation do
  let(:filename) { '20201020182259_backfill_kpack_lifecycle_data_association_to_droplets.rb' }
  let(:db) { Sequel::Model.db }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  let!(:bits_app) { VCAP::CloudController::AppModel.make }
  let!(:bits_package) { VCAP::CloudController::PackageModel.make(app: bits_app) }
  let!(:kpack_build) do
    VCAP::CloudController::BuildModel.make(
      app: bits_app,
      package: bits_package,
    )
  end
  let!(:eventual_kpack_droplet) { VCAP::CloudController::DropletModel.make(:docker, build: kpack_build) }
  let!(:kpack_lifecycle_data) { VCAP::CloudController::KpackLifecycleDataModel.make(build: kpack_build) }

  let(:docker_app) { VCAP::CloudController::AppModel.make(:docker) }
  let(:docker_package) { VCAP::CloudController::PackageModel.make(:docker, app: docker_app) }
  let(:docker_build) do
    VCAP::CloudController::BuildModel.make(:docker,
      app: docker_app,
      package: docker_package,
    )
  end
  let!(:docker_droplet) { VCAP::CloudController::DropletModel.make(:docker, build: docker_build) }

  let!(:kpack_lifecycle_data_no_build) { VCAP::CloudController::KpackLifecycleDataModel.make(build: nil) }

  let!(:kpack_build_no_droplet) do
    VCAP::CloudController::BuildModel.make(
      app: bits_app,
      package: bits_package,
    )
  end
  let!(:kpack_lifecycle_data_build_no_droplet) { VCAP::CloudController::KpackLifecycleDataModel.make(build: kpack_build_no_droplet) }

  before do
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, filename), tmp_migrations_dir)
  end

  it 'associates kpack_lifecycle_data with droplets associated to a kpack build' do
    expect(eventual_kpack_droplet.kpack?).to be false
    expect(eventual_kpack_droplet.docker?).to be true

    Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)

    eventual_kpack_droplet.reload
    kpack_lifecycle_data.reload

    expect(eventual_kpack_droplet.kpack?).to be true
    expect(eventual_kpack_droplet.lifecycle_data).to eq(kpack_lifecycle_data)
  end

  it 'ignores docker droplets that are not associated with a kpack build' do
    expect(docker_droplet.docker?).to be true

    Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)

    docker_droplet.reload

    expect(docker_droplet.kpack?).to be false
    expect(docker_droplet.docker?).to be true
    expect(docker_droplet.lifecycle_data).to be_a(VCAP::CloudController::DockerLifecycleDataModel)
  end

  it 'ignores kpack_lifecycle_data with no associated builds / builds with no droplets' do
    expect(kpack_lifecycle_data_no_build.droplet_guid).to be_nil
    expect(kpack_lifecycle_data_build_no_droplet.droplet_guid).to be_nil

    Sequel::Migrator.run(db, tmp_migrations_dir, table: :my_fake_table)

    kpack_lifecycle_data.reload
    kpack_lifecycle_data_no_build.reload

    expect(kpack_lifecycle_data_no_build.droplet_guid).to be_nil
    expect(kpack_lifecycle_data_build_no_droplet.droplet_guid).to be_nil
  end
end
