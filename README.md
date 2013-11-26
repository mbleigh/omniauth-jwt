# OmniAuth::JWT

[![Build Status](https://travis-ci.org/mbleigh/omniauth-jwt.png)](https://travis-ci.org/mbleigh/omniauth-jwt)

[JSON Web Token](http://self-issued.info/docs/draft-ietf-oauth-json-web-token.html) (JWT) is a simple
way to send verified information between two parties online. This can be useful as a mechanism for
providing Single Sign-On (SSO) to an application by allowing an authentication server to send a validated
claim and log the user in. This is how [Zendesk does SSO](https://support.zendesk.com/entries/23675367-Setting-up-single-sign-on-with-JWT-JSON-Web-Token-),
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
* **params_key:** the parameter we expect the JWT to be returned in from the authentication server.
  Defaults to `jwt`
* **user_claims_key:** where the authentication server provides the user claims nested within the token
  rather than at the root level, this option can be used to specify the key under which to find them.
  If a value is specified, it becomes a required claim and we expect to find the uid_claim and all
  claims specified under required_user_claims and info_map under this key.
  Defaults to nil
* **required_user_claims:** array of claims that are required under the user_claims_key to make this a
  valid authentication call.
  Defaults to nil

### Authentication Process

When you authenticate through `omniauth-jwt` you can send users to `/auth/jwt` and it will redirect
them to the URL specified in the `auth_url` option. From there, the provider must generate a JWT
and send it to the `/auth/jwt/callback` URL as a parameter identified by the params_key option
("jwt" by default):

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

### Integrating with Devise

Guide to using this gem as an oAuth provider in a Rails application using
[Devise](https://github.com/plataformatec/devise).  This guide
is lovingly adapted from the [devise wiki](https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview#google-oauth2-example).

Add the omniauth-jwt gem to your application in your Gemfile.

```ruby
gem 'omniauth-jwt'
```

Don't forget to run `bundle install`

Declare the provider in your config/initializers/devise.rb file and specify
your configuration.

```ruby
Devise.setup do |config|
  config.omniauth :jwt, "YOUR_SHARED_SECRET", {
    auth_url: 'https://example.com/path/to/authorisation',
    required_claims: ['iss', 'jti', 'nbf', 'exp', 'typ', 'aud', 'sub'],
    info_map: {'email' => 'mail', 'name' => 'cn'},
    uid_claim: 'mail',
    valid_within: 60,

    params_key: 'assertion',
    user_claims_key: 'your_providers_super_custom_user_claims_key',
    required_user_claims: ['mail', 'cn']
  }
end
```

Make your model (e.g. app/models/user.rb) omniauthable

```ruby
:omniauthable, :omniauth_providers => [:jwt]
```

Now you can add the helper to your views.

```ruby
<%= link_to "Sign in with your JWT provider", user_omniauth_authorize_path(:jwt) %>
```

By clicking on the above link, the user will be redirected to the URL specified in the
`auth_url` option you specified earlier. After inserting their credentials and approving the permission
requested, they will be redirected back to your application's callback method. To
implement a callback, the first step is to go back to our config/routes.rb file and tell
Devise in which controller we will implement Omniauth callbacks:

```ruby
devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks" }
```

Now we just add the file "app/controllers/users/omniauth_callbacks_controller.rb":

```ruby
# Skips the CSRF protection for the jwt action so that the session is retained
# and the user_return_to value can be used to redirect the user back to the
# page they originally requested after login.
protect_from_forgery :except => :jwt

def jwt
  raw_info = env['omniauth.auth'].extra.raw_info

  #Your validation of the claims received. Will vary depending on your requirements.
  #You may wish to store and validate the jti value to ensure there is no replay attack
  token_valid = (raw_info['iss'] == 'https://path/to/your/expected/issuer' &&
    raw_info['aud'] == 'https://path/to/your/expected/audience' &&
    Time.now > Time.at(raw_info['nbf']) &&
    Time.now < Time.at(raw_info['exp']) )

  if token_valid
    @user = User.find_for_jwt_oauth(env["omniauth.auth"]) # application specific logic
    if @user
      flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "jwt"
      sign_in_and_redirect @user, :event => :authentication
    else
      redirect_to user_session_path, :alert => 'Invalid admin user'
    end
  else
    redirect_to user_session_path, :alert => 'Bad token'
  end
end
```

After the controller is defined, we need to implement the find_for_jwt_oauth2 method
in our model (e.g. app/models/user.rb):

```ruby
def self.find_for_jwt_oauth(access_token)
  data = access_token.info

  #Your application specific logic for finding (or creating) a user object

  user
end
```

It's up to you how you implement the above method.  Here you can implement whatever
business logic your application needs to find or create a user object.

That should do it!


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
