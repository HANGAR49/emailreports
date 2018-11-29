require 'sidekiq'
require 'net/smtp'
require 'uri'
require 'json'
require 'erb'
require 'mail'
require "google_drive"


class MailWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'mailer', retry: 3

  settings = YAML.load(File.read("#{Dir.pwd}/config/config.yml"))

  # TODO: use any smtp based on a arg[:stmp] or default
  $smtp_label = 'mailgun'
  $smtp_host = settings['smtp'][$smtp_label]['host']
  $smtp_user = settings['smtp'][$smtp_label]['user']
  $smtp_pass = settings['smtp'][$smtp_label]['pass']
  $smtp_port = settings['smtp'][$smtp_label]['port']
  $smtp_domain = settings['smtp'][$smtp_label]['domain']


  def perform
    session = GoogleDrive::Session.from_service_account_key("#{Dir.pwd}/config/gserviceaccountconfig.json")
    ws1 = session.spreadsheet_by_key("1IPixH0u4OZTeVbsWHf0kE18YBl2EoYPaWWeHrY4kQwI").worksheets[0]
    ws2 = session.spreadsheet_by_key("1IPixH0u4OZTeVbsWHf0kE18YBl2EoYPaWWeHrY4kQwI").worksheets[1]
    ws3 = session.spreadsheet_by_key("1IPixH0u4OZTeVbsWHf0kE18YBl2EoYPaWWeHrY4kQwI").worksheets[2]
    ws4 = session.spreadsheet_by_key("1IPixH0u4OZTeVbsWHf0kE18YBl2EoYPaWWeHrY4kQwI").worksheets[3]

    (2..ws2.num_rows).each do |row|
          #Pick up Hubspot contact metrics
          @contact = ws1[row, 6]
          @owner = ws1[row, 4]
          @month = ws2[row, 1]
          @client = ws2[row, 2]
          @leads = ws2[row, 3]
          @replied = ws2[row, 7].to_i + ws2[row, 8].to_i
          @meetingset = ws2[row, 4]
          @meeting2bset1 = ws2[row, 5].to_i + ws2[row, 6].to_i
          @meeting2bset2 = ws2[row, 8].to_i

          #Pick up Woodpecker Campaign stats
          (2..ws3.num_rows).each do |row|
            case ws3[row, 1] == @month && ws3[row, 2] == @client
            when true
              @campaigns = ws3[row, 3]
              @wp_reachedout = ws3[row, 4]
              @wp_read =  sprintf "%.1f", ws3[row, 6].to_f / ws3[row, 5].to_f * 100
              @wp_replied = sprintf "%.1f", ws3[row, 7].to_f / ws3[row, 5].to_f * 100
              @wp_positive = sprintf "%.1f", ws3[row, 8].to_f / ws3[row, 5].to_f * 100
              @wp_negative = sprintf "%.1f", ws3[row, 10].to_f / ws3[row, 5].to_f * 100
              @wp_neutral = sprintf "%.1f", ws3[row, 9].to_f / ws3[row, 5].to_f * 100
            end
          end

=begin
          @campaign = Array.new
          (2..ws3.num_rows).each do |row|
            case ws3[row, 1] == @month && ws3[row, 2] == @client
            when true
              @campaign << "#{ws3[row, 3]}\n
              - Reached out: #{ws3[row, 4]}\n
              - Read: #{sprintf "%.1f", ws3[row, 6].to_f / ws3[row, 5].to_f * 100}%\n
              - Replied: #{sprintf "%.1f", ws3[row, 7].to_f / ws3[row, 5].to_f * 100}%\n
              - Positive: #{sprintf "%.1f", ws3[row, 8].to_f / ws3[row, 5].to_f * 100}%  Negative: #{sprintf "%.1f", ws3[row, 10].to_f / ws3[row, 5].to_f * 100}%  Neutral/Delayed: #{sprintf "%.1f", ws3[row, 9].to_f / ws3[row, 5].to_f * 100}%\n\n"
            end
          end
          @campaign = @campaign.join("\n")
=end

          #Pick up LinkedIn Reached Out and Replies from LinkedIn sheet
          @linkedIn = Array.new
          (2..ws4.num_rows).each do |row|
            case Time.parse(ws4[row, 1].to_s).strftime("%B") == @month && ws4[row, 4] == @client
            when true
              @linkedIn.push([ws4[row, 1], ws4[row, 2].to_i, ws4[row, 3].to_i, ws4[row, 4]])
            end
          end
          case @linkedIn.empty?
          when false
            @reachout = @linkedIn[0][1]
            @replied = @replied + @linkedIn[0][2]
          when true
            @reachout = ' - '
            @replied = ' - '
         end

      case ws1[row, 2].empty? || ws1[row, 3].empty? || ws1[row, 5].empty?
      when false
        puts "Sending Report to #{ws1[row, 5]}"
          from = ws1[row, 3]
          to = ws1[row, 5].split(',')
          sender = ws1[row, 4]
          recipients = ws1[row, 5]
  	      subject = "#{ws1[row, 2]} Status Update"

  	      # Render the mail template
          template = File.read("#{Dir.pwd}/templates/template.txt")
          renderer = ERB.new(template)
          output = renderer.result(binding)

  	      # Send email report
          smtp = Net::SMTP.new $smtp_host, $smtp_port
          smtp.enable_starttls
          smtp.start($smtp_domain, $smtp_user, $smtp_pass, :plain) do
             smtp.send_message(output, from, to)
          end
      end
    end
  end
end
