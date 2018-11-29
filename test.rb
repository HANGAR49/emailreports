require 'net/http'
require 'uri'
require 'json'
require "google_drive"

session = GoogleDrive::Session.from_service_account_key("#{Dir.pwd}/config/gserviceaccountconfig.json")
ws1 = session.spreadsheet_by_key("1IPixH0u4OZTeVbsWHf0kE18YBl2EoYPaWWeHrY4kQwI").worksheets[0]
ws3 = session.spreadsheet_by_key("1IPixH0u4OZTeVbsWHf0kE18YBl2EoYPaWWeHrY4kQwI").worksheets[2]


def running_campaigns!(key)
uri = URI.parse("https://api.woodpecker.co/rest/v1/campaign_list?status=RUNNING&status=COMPLETED")
request = Net::HTTP::Get.new(uri)
request.basic_auth("#{key}", "dummy")

req_options = {
  use_ssl: uri.scheme == "https",
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

campaign_ids = Array.new
JSON.parse(response.body).select do |each|
    campaign_ids << each['id']
end

return campaign_ids

end


def campaign_stats!(ids,key)
  uri = URI.parse("https://api.woodpecker.co/rest/v1/campaign_list?id=#{ids}&status=RUNNING&status=COMPLETED")
  request = Net::HTTP::Get.new(uri)
  request.basic_auth("#{key}", "dummy")

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  return JSON.parse(response.body)

end

line = 1

(2..ws1.num_rows).each do |row|
 begin
  case ws1[row, 7].empty?
  when false
      @wp_sent = 0
      @wp_delivered = 0
      @wp_opened = 0
      @wp_replied = 0
      @wp_positive = 0
      @wp_neutral = 0
      @wp_negative = 0
      @wp_campaigns = Array.new
      running_campaigns!(ws1[row, 7]).select do |campaign|
        campaign_stats!(campaign,ws1[row, 7]).select do |each|
          @wp_campaigns.push(each['name'].split('_').last)
          @wp_sent = @wp_sent.to_i + each['stats']['sent'].to_i
          @wp_delivered = @wp_delivered.to_i + each['stats']['delivery'].to_i
          @wp_opened = @wp_opened.to_i + each['stats']['opened'].to_i
          @wp_replied = @wp_replied.to_i + each['stats']['replied'].to_i
          @wp_positive = @wp_positive.to_i + each['stats']['interested'].to_i
          @wp_negative = @wp_negative.to_i + each['stats']['not_interested'].to_i
          @wp_neutral = @wp_neutral.to_i + each['stats']['maybe_later'].to_i
        end
      end
      line += 1
      ws3[line, 1] = Time.now.strftime("%B")
      ws3[line, 2] = ws1[row, 2]
      ws3[line, 3] = @wp_campaigns.join(', ')
      ws3[line, 4] = @wp_sent
      ws3[line, 5] = @wp_delivered
      ws3[line, 6] = @wp_opened
      ws3[line, 7] = @wp_replied
      ws3[line, 8] = @wp_positive
      ws3[line, 9] = @wp_negative
      ws3[line, 10] = @wp_neutral
      ws3.save
    end

  rescue => e
    puts "Error: #{e}\n on Woodpecker API #{ws1[row, 7]}"
  end
end
