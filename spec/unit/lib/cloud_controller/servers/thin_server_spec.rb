require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ThinServer do
    let(:valid_config_file_path) { File.join(Paths::CONFIG, 'cloud_controller.yml') }
    let(:config_file) { File.new(valid_config_file_path) }
    let(:app) { double(:app) }
    let(:logger) { double(:logger) }
    let(:argv) { [] }

    before :each do
      allow(logger).to receive :info
    end

    subject do
      config = Config.load_from_file(config_file.path, context: :api, secrets_hash: {})
      config.set(:external_host, 'some_local_ip')
      ThinServer.new(config, app, logger)
    end

    it 'starts thin server on set up bind address' do
      thin_server = double(:thin_server).as_null_object
      expect(Thin::Server).to receive(:new).with('some_local_ip', 8181, { signals: false }).and_return(thin_server)
      subject.start!
      expect(subject.instance_variable_get(:@thin_server)).to eq(thin_server)
    end

    describe 'start!' do
      let(:app) { double(:app) }
      let(:thin_server) { OpenStruct.new(start!: nil) }

      before do
        allow(Thin::Server).to receive(:new).and_return(thin_server)
        allow(thin_server).to receive(:start!)
        subject.start!
      end

      it 'gets the timeout from the config' do
        expect(thin_server.timeout).to eq(600)
      end

      it "uses thin's experimental threaded mode intentionally" do
        expect(thin_server.threaded).to eq(true)
      end

      it 'starts the thin server' do
        expect(thin_server).to have_received(:start!)
      end
    end
  end
end
