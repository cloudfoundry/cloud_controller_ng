require 'spec_helper'

module VCAP::CloudController
  describe RackAppBuilder do
    subject(:builder) do
      RackAppBuilder.new
    end

    let(:use_nginx) { false }

    before do
      TestConfig.override({
        nginx: {
          use_nginx: use_nginx,
        }
      })

      allow(Rack::CommonLogger).to receive(:new)
    end

    describe '#build' do
      let(:request_metrics) { nil }

      context 'when nginx is disabled' do
        it 'uses Rack::CommonLogger' do
          builder.build(TestConfig.config, request_metrics).to_app
          expect(Rack::CommonLogger).to have_received(:new).with(anything, instance_of(File))
        end
      end

      context 'when nginx is enabled' do
        let(:use_nginx) { true }

        it 'does not use Rack::CommonLogger' do
          builder.build(TestConfig.config, request_metrics).to_app
          expect(Rack::CommonLogger).to_not have_received(:new)
        end
      end

      it 'returns a Rack application' do
        expect(builder.build(TestConfig.config, request_metrics)).to be_a(Rack::Builder)
        expect(builder.build(TestConfig.config, request_metrics)).to respond_to(:call)
      end
    end
  end
end
