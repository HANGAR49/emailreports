require 'uri'
require 'net/http'
require 'json'
require 'chronic'
require 'redis'
require 'rack'
require "google_drive"
require 'dotenv/load'
require_relative "jor/errors"
require_relative "jor/storage"
require_relative "jor/collection"
require_relative "jor/doc"
require_relative "jor/server"
require_relative "jor/version"


session = GoogleDrive::Session.from_service_account_key("#{Dir.pwd}/config/gserviceaccountconfig.json")
ws1 = session.spreadsheet_by_key("#{ENV['GSHEET']}").worksheets[0]
ws2 = session.spreadsheet_by_key("#{ENV['GSHEET']}").worksheets[1]
ws3 = session.spreadsheet_by_key("#{ENV['GSHEET']}").worksheets[2]
ws4 = session.spreadsheet_by_key("#{ENV['GSHEET']}").worksheets[3]

module JOR
end

redis = Redis.new
$jor = JOR::Storage.new(redis)

$jor.destroy_collection("contacts")
$jor.create_collection("contacts", :auto_increment => true)


#GET Hubspot Metrics
@vidoffset = 0
loop do

uri = URI("https://api.hubapi.com/contacts/v1/lists/all/contacts/all?hapikey=#{ENV['HS']}&count=100&vidOffset=#{@vidoffset}&property=hubspot_team_id&property=hubspot_owner_id&property=hs_lead_status&property=month&property=email&property=tag&property=kind")
request = Net::HTTP::Get.new(uri)

response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  http.request(request)
end

contacts = JSON.parse(response.body)['contacts']
case JSON.parse(response.body)['has-more']
when true
 @vidoffset = JSON.parse(response.body)['vid-offset']
when false
  break
end

    begin
    contacts.select do |contact|

        case contact['properties']['month']['value'].downcase == Time.now.strftime("%B").downcase
        when true
              @month = contact['properties']['month']['value']
              puts "Creating #{contact['properties']['email']['value']}, #{contact['properties']['hubspot_team_id']['value']}, #{contact['properties']['hs_lead_status']['value']} for #{contact['properties']['month']['value']}"
             $jor.contacts.insert(
               {
                 "contact" => contact['properties']['email']['value'],
                 "team" => contact['properties']['hubspot_team_id']['value'],
                 "status" => contact['properties']['hs_lead_status']['value'],
                 "month" => contact['properties']['month']['value'],
                 "tag" => contact['properties']['tag']['value'],
                 "kind" => contact['properties']['kind']['value'],
                 "owner" => contact['properties']['hubspot_owner_id']['value']
               }
                )
           end
        end
    rescue => e
        puts "Error: #{e}"
    end
end


(2..ws1.num_rows).each do |row|
    @client = ws1[row, 2]
    @leads = $jor.contacts.find({ "team" => ws1[row, 1] })
    @opendeal = $jor.contacts.find({ "status" => "OPEN_DEAL", "team" => ws1[row, 1] })
    @setmeeting = $jor.contacts.find({ "status" => "SET_MEETING", "kind" => "LinkedIn", "team" => ws1[row, 1] })
    @ondeck = $jor.contacts.find({ "status" => "On Deck", "team" => ws1[row, 1] })
    @linkedinEngaged = $jor.contacts.find({ "status" => "LinkedIn – Engaged", "team" => ws1[row, 1] })
    @linkedinInterested = $jor.contacts.find({ "status" => "LinkedIn – Interested", "team" => ws1[row, 1] })

    ws2[row, 1] = @month
    ws2[row, 2] = @client
    ws2[row, 3] = @leads.count
    ws2[row, 4] = @opendeal.count
    ws2[row, 5] = @setmeeting.count
    ws2[row, 6] = @ondeck.count
    ws2[row, 7] = @linkedinEngaged.count
    ws2[row, 8] = @linkedinInterested.count
    ws2.save
    @leads, @opendeal, @setmeeting, @ondeck, @linkedinEngaged, @linkedinInterested = 0
end


#GET Woodpeccker Metrics
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
