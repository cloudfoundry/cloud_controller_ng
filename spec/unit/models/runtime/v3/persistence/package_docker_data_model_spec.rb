require 'spec_helper'

module VCAP::CloudController
  describe PackageDockerDataModel do
    describe '#credentials=' do
      let(:creds) do
        {
          user: 'user',
          password: 'pw',
          login_server: 'login_server',
          email: 'email'
        }
      end
      it 'aggregates assigning credential info' do
        model = PackageDockerDataModel.new
        model.credentials = (creds)
        expect(model.user).to eq('user')
        expect(model.password).to eq('pw')
        expect(model.login_server).to eq('login_server')
        expect(model.email).to eq('email')
      end
    end

    describe '#credentials' do
      let(:creds) do
        {
          user: 'user',
          password: 'pw',
          login_server: 'login_server',
          email: 'email'
        }
      end

      it 'returns a hash of credentials' do
        model = PackageDockerDataModel.new
        model.credentials = (creds)
        expect(model.credentials).to eq(creds)
      end
    end

    describe 'encryption' do
      let(:package_docker_data) do
        data = {
          image: 'registry/image:latest',
          user: plain_user,
          password: plain_password,
          email: plain_email,
          login_server: plain_login_server,
          store_image: true
        }
        PackageDockerDataModel.create(data)
      end

      let(:plain_email) { 'email@exmple.com' }
      let(:plain_user) { 'username' }
      let(:plain_password) { 'secret' }
      let(:plain_login_server) { 'https://index.docker.io/v1/' }

      it 'encrypts credential info at rest' do
        expect(package_docker_data.encrypted_email).not_to eq(plain_email)
        expect(package_docker_data.encrypted_password).not_to eq(plain_password)
        expect(package_docker_data.encrypted_user).not_to eq(plain_user)
        expect(package_docker_data.encrypted_login_server).not_to eq(plain_login_server)
      end

      it 'decrypts info' do
        expect(package_docker_data.email).to eq(plain_email)
        expect(package_docker_data.password).to eq(plain_password)
        expect(package_docker_data.user).to eq(plain_user)
        expect(package_docker_data.login_server).to eq(plain_login_server)
      end
    end

    describe 'associations' do
      let(:package) { PackageModel.make }

      it 'is associated with a package' do
        data = PackageDockerDataModel.new(package: package)
        expect(data.save.reload.package).to eq(package)
      end
    end
  end
end
