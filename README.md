# OmniAuth::JWT

[![Build Status](https://travis-ci.org/mbleigh/omniauth-jwt.png)](https://travis-ci.org/mbleigh/omniauth-jwt)

[JSON Web Token](http://self-issued.info/docs/draft-ietf-oauth-json-web-token.html) (JWT) is a simple
way to send verified information between two parties online. This can be useful as a mechanism for
providing Single Sign-On (SSO) to an application by allowing an authentication server to send a validated
claim and log the user in. This is how [Zendesk does SSO](https://support.zendesk.com/hc/en-us/articles/4408845838874-Enabling-JWT-JSON-Web-Token-single-sign-on),
for example.

OmniAuth::JWT provides a clean, simple wrapper on top of JWT so that you can easily implement this kind
of SSO either between your own applications or allow third parties to delegate authentication.

## Installation

Add this line to your application's Gemfile:

    gem 'omniauth-jwt'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install omniauth-jwt

## Usage

You use OmniAuth::JWT just like you do any other OmniAuth strategy:

```ruby
use OmniAuth::JWT, 'SHAREDSECRET', auth_url: 'http://example.com/login'
```

The first parameter is the shared secret that will be used by the external authenticator to verify
that. You must also specify the `auth_url` option to tell the strategy where to redirect to log
in. Other available options are:

* **algorithm:** the algorithm to use to decode the JWT token. This is `HS256` by default but can
  be set to anything supported by [ruby-jwt](https://github.com/progrium/ruby-jwt)
* **uid_claim:** this determines which claim will be used to uniquely identify the user. Defaults
  to `email`
* **required_claims:** array of claims that are required to make this a valid authentication call.
  Defaults to `['name', 'email']`
* **info_map:** array mapping claim values to info hash values. Defaults to mapping `name` and `email`
  to the same in the info hash.
* **valid_within:** integer of how many seconds of time skew you will allow. Defaults to `nil`. If this
  is set, the `iat` claim becomes required and must be within the specified number of seconds of the
  current time. This helps to prevent replay attacks.
  
### Authentication Process

When you authenticate through `omniauth-jwt` you can send users to `/auth/jwt` and it will redirect
them to the URL specified in the `auth_url` option. From there, the provider must generate a JWT
and send it to the `/auth/jwt/callback` URL as a "jwt" parameter:

    /auth/jwt/callback?jwt=ENCODEDJWTGOESHERE
    
An example of how to do that in Sinatra:

```ruby
require 'jwt'

get '/login/sso/other-app' do
  # assuming the user is already logged in and this is available as current_user
  claims = {
    id: current_user.id,
    name: current_user.name,
    email: current_user.email,
    iat: Time.now.to_i
  }
  
  payload = JWT.encode(claims, ENV['SSO_SECRET'])
  redirect "http://other-app.com/auth/jwt/callback?jwt=#{payload}"
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
