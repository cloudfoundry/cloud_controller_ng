require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Procfile do
    describe '.load' do
      it 'loads a procfile into a hash' do
        hash = Procfile.load('a: command')
        expect(hash).to eq(a: 'command')
      end

      it 'supports multiple processes' do
        hash = Procfile.load(<<PROCFILE)
web: my-web args
this is a comment
workerz: daworker args multiple
PROCFILE
        expect(hash).to eq(
          web: 'my-web args',
          workerz: 'daworker args multiple',
        )
      end

      it 'supports windows linebreaks' do
        hash = Procfile.load("web: my-web args\r\nworkerz: daworker args multiple")
        expect(hash).to eq(
          web: 'my-web args',
          workerz: 'daworker args multiple',
        )
      end

      it 'raises ParseError if procfile is invalid' do
        expect {
          Procfile.load('grabage')
        }.to raise_error(Procfile::ParseError)
      end
    end

    describe '.validate' do
      let(:procfile) { 'web: adfasdfasdf' }
      it 'returns the procile body' do
        expect(Procfile.validate(procfile)).to eq(procfile)
      end

      it 'supports multiple processes' do
        hash = Procfile.load(<<PROCFILE)
web: my-web args
this is a comment
workerz: daworker args multiple
PROCFILE
        expect(hash).to eq(
          web: 'my-web args',
          workerz: 'daworker args multiple',
        )
      end

      it 'supports windows linebreaks' do
        hash = Procfile.load("web: my-web args\r\nworkerz: daworker args multiple")
        expect(hash).to eq(
          web: 'my-web args',
          workerz: 'daworker args multiple',
        )
      end

      it 'raises ParseError if procfile is invalid' do
        expect {
          Procfile.load('grabage')
        }.to raise_error(Procfile::ParseError)
      end
    end
  end
end
