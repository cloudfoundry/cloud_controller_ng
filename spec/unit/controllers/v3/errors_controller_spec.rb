require 'rails_helper'
require 'action_dispatch/middleware/params_parser'

RSpec.describe ErrorsController, type: :controller do
  describe '#not_found' do
    it 'returns an error' do
      get :not_found

      expect(response.status).to eq(404)
      expect(parsed_body['errors'].first['title']).to eq('CF-NotFound')
    end
  end

  describe '#internal_error' do
    before do
      @request.env.merge!('action_dispatch.exception' => StandardError.new('sad things'))
    end

    it 'returns the error from the request env in action_dispatch.exception' do
      get :internal_error

      expect(response.status).to eq(500)
      expect(parsed_body['errors'].first['detail']).to eq('An unknown error occurred.')
    end
  end

  describe '#bad_request' do
    it 'returns an error' do
      get :bad_request

      expect(response.status).to eq(400)
      expect(parsed_body['errors'].first['title']).to eq('CF-InvalidRequest')
    end

    context 'when the json is invalid' do
      before do
        @request.env['action_dispatch.exception'] = ActionDispatch::ParamsParser::ParseError.new(nil, nil)
      end

      it 'it returns an error' do
        get :bad_request

        expect(response.status).to eq(400)
        expect(parsed_body['errors'].first['detail']).to eq('Request invalid due to parse error: invalid request body')
      end
    end
  end
end
