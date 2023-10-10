require 'spec_helper'
require 'actions/package_update'

module VCAP::CloudController
  RSpec.describe PackageUpdate do
    subject(:package_update) { PackageUpdate.new }

    describe '#update' do
      let(:body) do
        {
          metadata: {
            labels: {
              freaky: 'wednesday'
            },
            annotations: {
              tokyo: 'grapes'
            }
          }
        }
      end
      let(:package) { PackageModel.make }
      let(:message) { PackageUpdateMessage.new(body) }

      it 'updates the package metadata' do
        expect(message).to be_valid
        package_update.update(package, message)

        package.reload
        expect(package).to have_labels({ key_name: 'freaky', value: 'wednesday' })
        expect(package).to have_annotations({ key_name: 'tokyo', value: 'grapes' })
      end
    end

    describe 'update docker credentials' do
      let(:body) do
        {
          username: 'Udo',
          password: 'It is a secret'
        }
      end
      let(:package) { PackageModel.make(type: 'docker', docker_image: 'image-magick.com') }
      let(:message) { PackageUpdateMessage.new(body) }

      it "updates the package's docker credentials"  do
        expect(message).to be_valid
        package_update.update(package, message)

        package.reload
        expect(package.docker_username).to eq('Udo')
        expect(package.docker_password).to eq('It is a secret')
      end
    end

    describe 'update docker username' do
      let(:body) do
        {
          username: 'Walz'
        }
      end
      let(:package) { PackageModel.make(type: 'docker', docker_image: 'image-magick.com') }
      let(:message) { PackageUpdateMessage.new(body) }

      it "updates the package's docker username" do
        expect(message).to be_valid
        package_update.update(package, message)

        package.reload
        expect(package.docker_username).to eq('Walz')
        expect(package.docker_password).to be_nil
      end
    end

    describe 'update docker password' do
      let(:body) do
        {
          password: 'Absolutely secret'
        }
      end
      let(:package) { PackageModel.make(type: 'docker', docker_image: 'image-magick.com') }
      let(:message) { PackageUpdateMessage.new(body) }

      it "updates the package's docker password" do
        expect(message).to be_valid
        package_update.update(package, message)

        package.reload
        expect(package.docker_username).to be_nil
        expect(package.docker_password).to eq('Absolutely secret')
      end
    end
  end
end
