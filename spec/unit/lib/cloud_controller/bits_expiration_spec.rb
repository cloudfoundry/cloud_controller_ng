require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BitsExpiration do
    before do
      allow(Config).to receive(:config) { config }
    end

    let(:app) { AppModel.make }
    let(:blobstore) do
      CloudController::DependencyLocator.instance.droplet_blobstore
    end

    let(:config) do
      {
        packages: { max_valid_packages_stored: 5 },
        droplets: { max_staged_droplets_stored: 5 }
      }
    end

    let(:changed_config) do
      {
        packages: { max_valid_packages_stored: 10 },
        droplets: { max_staged_droplets_stored: 10 }
      }
    end

    it 'is configurable' do
      expect(BitsExpiration.new(changed_config).droplets_storage_count).to eq(10)
      expect(BitsExpiration.new(changed_config).packages_storage_count).to eq(10)
    end

    context 'with an app with few droplets / packages' do
      it 'does not mark any as expired' do
        3.times { DropletModel.make(state: DropletModel::STAGED_STATE, app_guid: app.guid) }
        3.times { PackageModel.make(state: PackageModel::READY_STATE, app_guid: app.guid) }
        BitsExpiration.new.expire_droplets!(app)
        BitsExpiration.new.expire_packages!(app)
        expect(DropletModel.where(state: DropletModel::EXPIRED_STATE).count).to eq(0)
        expect(PackageModel.where(state: PackageModel::EXPIRED_STATE).count).to eq(0)
      end
    end

    context 'with droplets' do
      before do
        t        = Time.now
        @current = DropletModel.make(:staged,
          app_guid:     app.guid,
          created_at:   t
        )
        app.update(droplet: @current)

        10.times do |i|
          DropletModel.make(:staged,
            app_guid:     app.guid,
            created_at:   t + i,
          )
        end
      end

      it 'expires droplets' do
        expiration = BitsExpiration.new
        expiration.expire_droplets!(app)
        remaining_droplet_models = DropletModel.where(state: DropletModel::STAGED_STATE, app_guid: app.guid).count
        num_of_droplets_to_keep  = expiration.droplets_storage_count + 1
        expect(remaining_droplet_models).to eq(num_of_droplets_to_keep)
      end

      it 'expires all but the newest n droplets' do
        BitsExpiration.new.expire_droplets!(app)
        remaining_droplet_models = DropletModel.where(state: DropletModel::STAGED_STATE, app_guid: app.guid).exclude(guid: @current.guid)
        expired_droplets         = DropletModel.where(state: DropletModel::EXPIRED_STATE, app_guid: app.guid)

        oldest_remaining_droplet = remaining_droplet_models.map(&:created_at).min
        newest_expired_droplet   = expired_droplets.map(&:created_at).max

        expect(oldest_remaining_droplet > newest_expired_droplet).to be(true)
      end

      it 'does not delete the current droplet' do
        BitsExpiration.new.expire_droplets!(app)
        app.reload && @current.reload
        expect(app.droplet).to eq(@current)
        expect(@current.state).to eq(DropletModel::STAGED_STATE)
      end

      it 'enqueues a job to delete the blob' do
        expect { BitsExpiration.new.expire_droplets!(app) }.to change { Delayed::Job.count }.from(0).to(5)
        expect(Delayed::Job.all? { |j| j.handler.include?('DeleteExpiredDropletBlob') }).to be_truthy
      end
    end

    context 'with packages' do
      before do
        t                = Time.now
        @current_package = PackageModel.make(
          package_hash: 'current_package_hash',
          state:        PackageModel::READY_STATE,
          app_guid:     app.guid,
          created_at:   t
        )
        @current = DropletModel.make(:staged,
          app_guid:     app.guid,
          package_guid: @current_package.guid
        )
        app.update(droplet: @current)

        10.times do |i|
          PackageModel.make(package_hash: 'real hash!',
                            state:                        PackageModel::READY_STATE,
                            app_guid:                     app.guid,
                            created_at:                   t + i)
        end
      end

      it 'expires old packages' do
        expiration = BitsExpiration.new
        expiration.expire_packages!(app)
        num_of_packages_to_keep = expiration.packages_storage_count + 1
        remaining_packages      = PackageModel.where(state: PackageModel::READY_STATE, app_guid: app.guid)
        expect(remaining_packages.count).to eq(num_of_packages_to_keep)
      end

      it 'does not delete the package related to the current droplet' do
        BitsExpiration.new.expire_packages!(app)
        app.reload && @current_package.reload
        expect(@current_package.state).to eq(PackageModel::READY_STATE)
      end

      it 'does not blow up if the current droplet has no package' do
        app.droplet.update(package_guid: nil)
        app.droplet.save

        expect { BitsExpiration.new.expire_packages!(app) }.not_to raise_error
      end

      it 'enqueues a job to delete the blob' do
        expect { BitsExpiration.new.expire_packages!(app) }.to change { Delayed::Job.count }.from(0).to(5)
        expect(Delayed::Job.all? { |j| j.handler.include?('DeleteExpiredPackageBlob') }).to be_truthy
      end
    end
  end
end
