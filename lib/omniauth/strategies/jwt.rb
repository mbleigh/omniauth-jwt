require 'omniauth'
require 'jwt'

module OmniAuth
  module Strategies
    class JWT
      class ClaimInvalid < StandardError; end
      
      include OmniAuth::Strategy
      
      args [:secret]
      
      option :secret, nil
      option :algorithm, 'HS256'
      option :uid_claim, 'email'
      option :required_claims, %w(name email)
      option :info_map, {"name" => "name", "email" => "email"}
      option :auth_url, nil
      option :valid_within, nil

      option :params_key, 'jwt'
      option :user_claims_key, nil
      option :required_user_claims, nil

      def request_phase
        redirect options.auth_url
      end
      
      def decoded
        @decoded ||= ::JWT.decode(request.params[options.params_key], options.secret, options.algorithm)
        (options.required_claims || []).each do |field|
          raise ClaimInvalid.new("Missing required '#{field}' claim.") if !@decoded.key?(field.to_s)
        end

        if options.required_user_claims
          raise ClaimInvalid.new("Missing required 'user_claims_key'.") if !@decoded[options.user_claims_key]

          options.required_user_claims.each do |field|
            raise ClaimInvalid.new("Missing required '#{field}' claim.") if !@decoded[options.user_claims_key].key?(field.to_s)
          end
        end

        raise ClaimInvalid.new("Missing required 'iat' claim.") if options.valid_within && !@decoded["iat"]
        raise ClaimInvalid.new("'iat' timestamp claim is too skewed from present.") if options.valid_within && (Time.now.to_i - @decoded["iat"]).abs > options.valid_within
        @decoded
      end
      
      def callback_phase
        super
      rescue ClaimInvalid => e
        fail! :claim_invalid, e
      end

      uid{ options.user_claims_key ? decoded[options.user_claims_key][options.uid_claim] : decoded[options.uid_claim] }

      extra do
        {:raw_info => decoded}
      end
      
      info do
        claims = options.user_claims_key ? decoded[options.user_claims_key] : decoded

        options.info_map.inject({}) do |h,(k,v)|
          h[k.to_s] = claims[v.to_s]
          h
        end
      end
    end
    
    class Jwt < JWT; end
  end
end