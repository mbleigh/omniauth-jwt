require 'spec_helper'

describe OmniAuth::Strategies::JWT do
  let(:response_json){ MultiJson.load(last_response.body) }
  let(:args){ ['imasecret', {auth_url: 'http://example.com/login'}] }
  
  let(:app){
    the_args = args
    Rack::Builder.new do |b|
      b.use Rack::Session::Cookie, secret: 'sekrit'
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
      encoded = JWT.encode({name: 'Bob', email: 'steve@example.com'}, 'imasecret')
      get '/auth/jwt/callback?jwt=' + encoded
      expect(response_json["info"]["email"]).to eq("steve@example.com")
    end
    
    it 'should not work without required fields' do
      encoded = JWT.encode({name: 'Steve'}, 'imasecret')
      get '/auth/jwt/callback?jwt=' + encoded
      expect(last_response.status).to eq(302)
    end
    
    it 'should assign the uid' do
      encoded = JWT.encode({name: 'Steve', email: 'dude@awesome.com'}, 'imasecret')
      get '/auth/jwt/callback?jwt=' + encoded
      expect(response_json["uid"]).to eq('dude@awesome.com')
    end
    
    context 'with a :valid_within option set' do
      let(:args){ ['imasecret', {auth_url: 'http://example.com/login', valid_within: 300}] }
      
      it 'should work if the iat key is within the time window' do
        encoded = JWT.encode({name: 'Ted', email: 'ted@example.com', iat: Time.now.to_i}, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(200)
      end
      
      it 'should not work if the iat key is outside the time window' do
        encoded = JWT.encode({name: 'Ted', email: 'ted@example.com', iat: Time.now.to_i + 500}, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(302)
      end
      
      it 'should not work if the iat key is missing' do
        encoded = JWT.encode({name: 'Ted', email: 'ted@example.com'}, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(302)
      end
    end

    context 'with a :params_key option set' do
      let(:args){ ['imasecret', {auth_url: 'http://example.com/login', params_key: 'assertion'}] }

      it 'should decode the response' do
        encoded = JWT.encode({name: 'Bob', email: 'steve@example.com'}, 'imasecret')
        get '/auth/jwt/callback?assertion=' + encoded
        expect(response_json["info"]["email"]).to eq("steve@example.com")
      end
    end

    context 'with a user_claims_key option set' do
      let(:args){ ['imasecret', {
        auth_url: 'http://example.com/login',
        user_claims_key: 'someFunkyUserClaimsKey',
        required_claims: [],
        required_user_claims: ['name', 'email']
      }] }

      it 'should decode the response' do
        encoded = JWT.encode({someFunkyUserClaimsKey: {name: 'Bob', email: 'steve@example.com'} }, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(response_json["info"]["email"]).to eq("steve@example.com")
      end

      it 'should not work without required user fields' do
        encoded = JWT.encode({ 'someFunkyUserClaimsKey' => {name: 'Steve'} }, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(302)
      end

      it 'should not work without user_claims_key present' do
        encoded = JWT.encode({someFunkyUserClaimsKeyZZZ: {name: 'Bob', email: 'steve@example.com'} }, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(last_response.status).to eq(302)
      end

      it 'should assign the uid' do
        encoded = JWT.encode({'someFunkyUserClaimsKey' => {name: 'Steve', email: 'dude@awesome.com'} }, 'imasecret')
        get '/auth/jwt/callback?jwt=' + encoded
        expect(response_json["uid"]).to eq('dude@awesome.com')
      end
    end

  end
end