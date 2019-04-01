require 'spec_helper'
require 'jobs/error_translator_job'

module VCAP::CloudController::Jobs
  RSpec.describe ErrorTranslatorJob do
    let(:job) { double }
    let(:error_translator_job) { ErrorTranslatorJob.new(job) }

    describe '#perform' do
      it 'runs the provided job' do
        expect(job).to receive(:perform)
        error_translator_job.perform
      end
    end

    describe '#error' do
      it 'passes error to provided job' do
        err = StandardError.new('oops')
        expect(job).to receive(:error).with(job, err)
        error_translator_job.error(job, err)
      end

      context 'when overriden' do
        class CustomErrorTranslator < ErrorTranslatorJob
          def translate_error(e)
            StandardError.new('translated-oops')
          end
        end

        let(:error_translator_job) { CustomErrorTranslator.new(job) }

        it 'translates error and passes it to provided job' do
          expect(job).to receive(:error).with(job, StandardError.new('translated-oops'))

          error_translator_job.error(job, StandardError.new('oops'))
        end
      end
    end
  end
end
