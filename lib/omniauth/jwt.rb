# External gems
require "version_gem"

# This gem
require "omniauth/jwt/version"
require "omniauth/strategies/jwt"

Omniauth::JWT::Version.class_eval do
  extend VersionGem::Basic
end
