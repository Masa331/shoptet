require_relative 'shoptet/request'
require_relative 'shoptet/api'
require_relative 'shoptet/shop'

module Shoptet
  def self.version
    '0.0.1'
  end

  attr_reader :oauth_api_token_url, :oauth_token

  def initialize(oauth_api_token_url, oauth_token)
    @oauth_api_token_url = oauth_api_token_url
    @oauth_token = oauth_token
  end
end
