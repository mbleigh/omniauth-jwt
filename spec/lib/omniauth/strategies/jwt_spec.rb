require 'spec_helper'

describe OmniAuth::Strategies::JWT do
  let(:response_json){ JSON.parse(last_response.body) }
  let(:secret) { SecureRandom.hex(10) }
  let(:args){ [secret, {auth_url: 'http://example.com/login'}] }

  let(:app){
    the_args = args
    Rack::Builder.new do |b|
      b.use Rack::Session::Cookie, secret: SecureRandom.hex(32)
      b.use OmniAuth::Strategies::JWT, *the_args
      b.run lambda{|env| [200, {}, [(env['omniauth.auth'] || {}).to_json]]}
    end
  }

  context 'request phase' do
    it 'should redirect to the configured login url' do
      get '/auth/jwt'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq('http://example.com/login')
    end
  end

  context 'callback phase' do
    it 'should decode the response' do
      encoded = JWT.encode({name: 'Bob', email: 'steve@example.com'}, secret)
      get '/auth/jwt/callback?jwt=' + encoded
      expect(response_json["info"]["email"]).to eq("steve@example.com")
    end

    it 'should not work without required fields' do
      encoded = JWT.encode({name: 'Steve'}, secret)
      get '/auth/jwt/callback?jwt=' + encoded
      expect(last_response.status).to eq(302)
    end

    it 'should assign the uid' do
      encoded = JWT.encode({name: 'Steve', email: 'dude@awesome.com'}, secret)
      get '/auth/jwt/callback?jwt=' + encoded
      expect(response_json["uid"]).to eq('dude@awesome.com')
    end

    context 'with a non-default encoding algorithm' do
      let(:args){ [secret, {auth_url: 'http://example.com/login', decode_options: { algorithms: ['HS512', 'HS256'] }}] }

      it 'should decode the response with an allowed algorithm' do
        encoded = JWT.encode({name: 'Bob', email: 'steve@example.com'}, secret, 'HS512')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(JSON.parse(last_response.body)["info"]["email"]).to eq("steve@example.com")

        encoded = JWT.encode({name: 'Bob', email: 'steve@example.com'}, secret, 'HS256')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(JSON.parse(last_response.body)["info"]["email"]).to eq("steve@example.com")
      end

      it 'should fail decoding the response with a different algorithm' do
        encoded = JWT.encode({name: 'Bob', email: 'steve@example.com'}, secret, 'HS384')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.headers["Location"]).to include("/auth/failure")
      end
    end

    context 'with a :valid_within option set' do
      let(:args){ [secret, {auth_url: 'http://example.com/login', valid_within: 300}] }

      it 'should work if the iat key is within the time window' do
        encoded = JWT.encode({name: 'Ted', email: 'ted@example.com', iat: Time.now.to_i}, secret)
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(200)
      end

      it 'should not work if the iat key is outside the time window' do
        encoded = JWT.encode({name: 'Ted', email: 'ted@example.com', iat: Time.now.to_i + 500}, secret)
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(302)
      end

      it 'should not work if the iat key is missing' do
        encoded = JWT.encode({name: 'Ted', email: 'ted@example.com'}, secret)
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(302)
      end
    end
  end
end
