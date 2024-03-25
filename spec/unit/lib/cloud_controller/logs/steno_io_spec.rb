require 'spec_helper'

module VCAP::CloudController::Logs
  RSpec.describe StenoIO do
    let(:logger) { double(:logger) }
    let(:level) { :info }

    subject { StenoIO.new(logger, level) }

    describe '#write' do
      it 'writes to the logger' do
        expect(logger).to receive(:log).with(level, 'message')

        subject.write('message')
      end
    end

    describe '#sync' do
      it 'returns true' do
        expect(subject.sync).to be(true)
      end
    end
  end
end
