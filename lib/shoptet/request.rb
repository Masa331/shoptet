require 'net/http'

#TODO: keep_alive_timeout ?

class Shoptet
  module UrlHelpers
    def assemble_uri base, params = {}
      u = URI(base)
      u.query = URI.encode_www_form(params) if params.any?

      u.to_s
    end
  end

  class Request
    def self.get uri, headers
      attempt ||= 0
      attempt += 1

      parsed_uri = URI(uri)

      http = Net::HTTP.new parsed_uri.host, parsed_uri.port
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 10
      http.write_timeout = 10
      http.ssl_timeout = 10

      request = Net::HTTP::Get.new parsed_uri
      headers.each do |key, value|
        request[key] = value
      end

      response = http.request request

      JSON.parse response.body
    rescue Net::OpenTimeout
      retry if attempt < 4
    end

    def self.post uri, body
      req = Net::HTTP::Post.new uri
      req.set_form_data body

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request req
      end

      JSON.parse res.body
    end
  end
end
