require 'omniauth'
require 'jwt'

module OmniAuth
  module Strategies
    class JWT
      class ClaimInvalid < StandardError; end
      class BadJwt < StandardError; end

      include OmniAuth::Strategy

      args [:secret]

      option :secret, nil
      option :decode_options, {}
      option :jwks_loader
      option :algorithm, 'HS256' # overridden by options.decode_options[:algorithms]
      option :decode_options, {}
      option :uid_claim, 'email'
      option :required_claims, %w(name email)
      option :info_map, { name: "name", email: "email" }
      option :auth_url, nil
      option :valid_within, nil

      def request_phase
        redirect options.auth_url
      end

      def decoded
        begin
          secret = if defined?(OpenSSL)
                     case options.algorithm
                     when *%w[RS256 RS384 RS512]
                       OpenSSL::PKey::RSA.new(options.secret).public_key
                     when *%w[ES256 ES384 ES512]
                       OpenSSL::PKey::EC.new(options.secret)
                     when *%w[HS256 HS384 HS512]
                       options.secret
                     else
                       raise NotImplementedError, "Unsupported algorithm: #{options.algorithm}"
                     end
                   else
                     options.secret
                   end

          # JWT.decode can handle either algorithms or algorithm, but not both.
          default_algos = options.decode_options.key?(:algorithms) ? options.decode_options[:algorithms] : [options.algorithm]
          @decoded ||= ::JWT.decode(
            request.params['jwt'],
            secret,
            true,
            options.decode_options.merge(
              {
                algorithms: default_algos,
                jwks: options.jwks_loader
              }.delete_if {|_, v| v.nil? }
            )
          )[0]
        rescue Exception => e
          raise BadJwt.new("#{e.class}: #{e.message}")
        end
        (options.required_claims || []).each do |field|
          raise ClaimInvalid.new("Missing required '#{field}' claim.") if !@decoded.key?(field.to_s)
        end
        raise ClaimInvalid.new("Missing required 'iat' claim.") if options.valid_within && !@decoded["iat"]
        if options.valid_within && (Time.now.to_i - @decoded["iat"]).abs > options.valid_within.to_i
          raise ClaimInvalid, "'iat' timestamp claim is too skewed from present"
        end

        @decoded
      end

      def callback_phase
        super
      rescue BadJwt => e
        fail! 'bad_jwt', e
      rescue ClaimInvalid => e
        fail! :claim_invalid, e
      end

      uid{ decoded[options.uid_claim] }

      extra do
        {:raw_info => decoded}
      end

      info do
        options.info_map.each_with_object({}) do |(k, v), h|
          h[k.to_s] = decoded[v.to_s]
        end
      end
    end

    class Jwt < JWT; end
  end
end
