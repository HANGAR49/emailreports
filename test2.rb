require 'net/http'
require 'uri'
require 'json'

uri = URI.parse("https://api.woodpecker.co/rest/v1/campaign_list?status=RUNNING&status=COMPLETED")
request = Net::HTTP::Get.new(uri)
request.basic_auth("34712.7eb7fa69d2369696904b291d16e45e5c313e3ea539d1047019ea658f36b9a167", "dummy")

req_options = {
  use_ssl: uri.scheme == "https",
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

puts JSON.parse(response.body)
