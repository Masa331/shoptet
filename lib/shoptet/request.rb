require 'net/http'

module Shoptet
  class Request
    def self.get(uri, headers)
      parsed_uri = URI(uri)

      http = Net::HTTP.new(parsed_uri.host, parsed_uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(parsed_uri)
      headers.each do |key, value|
        request[key] = value
      end

      response = http.request(request)

      JSON.parse response.body
    end
  end
end
