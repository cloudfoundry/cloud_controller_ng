require 'spec_helper'
require 'cloud_controller/diego/windows_environment_sage'

module VCAP::CloudController::Diego
  RSpec.describe WindowsEnvironmentSage do
    let(:parent_app) { VCAP::CloudController::AppModel.make }
    let(:credential_refs) { [] }

    describe '.ponder' do
      before do
        allow(parent_app).to receive(:windows_gmsa_credential_refs).and_return(credential_refs)
      end

      context 'when the app has Windows gmsa credential refs' do
        context 'when there is exactly one credential ref' do
          let(:credential_refs) do
            [
              '/credhub-windows-gmsa-service-broker/credhub-windows-gmsa/18292699-e63d-4d76-8a2e-8cba5e3f1760/credentials'
            ]
          end

          it 'a Diego-formatted WINDOWS_GMSA_CREDENTIAL_REF env var' do
            expect(WindowsEnvironmentSage.ponder(parent_app)).to eq([
              ::Diego::Bbs::Models::EnvironmentVariable.new(
                name: 'WINDOWS_GMSA_CREDENTIAL_REF',
                value: '/credhub-windows-gmsa-service-broker/credhub-windows-gmsa/18292699-e63d-4d76-8a2e-8cba5e3f1760/credentials'
              )
            ])
          end
        end

        context 'when there are more than one credential refs' do
          let(:credential_refs) do
            [
              '/credhub-windows-gmsa-service-broker/credhub-windows-gmsa/18292699-e63d-4d76-8a2e-8cba5e3f1760/credentials',
              '/credhub-windows-gmsa-service-broker/credhub-windows-gmsa/additional/credentials'
            ]
          end

          it 'creates an env var using the first credential' do
            expect(WindowsEnvironmentSage.ponder(parent_app)).to eq([
              ::Diego::Bbs::Models::EnvironmentVariable.new(
                name: 'WINDOWS_GMSA_CREDENTIAL_REF',
                value: '/credhub-windows-gmsa-service-broker/credhub-windows-gmsa/18292699-e63d-4d76-8a2e-8cba5e3f1760/credentials'
              )
            ])
          end
        end
      end

      context 'when the app DOES NOT have Windows gmsa credential refs' do
        it 'returns an empty array' do
          expect(WindowsEnvironmentSage.ponder(parent_app)).to eq([])
        end
      end
    end
  end
end
