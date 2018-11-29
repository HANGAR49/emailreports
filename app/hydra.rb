require 'sinatra/base'
require 'sidekiq'
require 'sidekiq/api'
require 'sidekiq/web'
require 'json'


Dir[File.join(__dir__, '../workers/', '*.rb')].each { |file| require_relative file }

$stdout.sync = true


class App < Sinatra::Application

  get '/status' do
		stats = Sidekiq::Stats.new
		workers = Sidekiq::Workers.new
		"
		<p>Processed: #{stats.processed}</p>
		<p>In Progress: #{workers.size}</p>
		<p>Enqueued: #{stats.enqueued}</p>
		<p><a href='/'>Refresh</a></p>
		<p><a href='/add_job'>Add Job</a></p>
		<p><a href='/sidekiq'>Dashboard</a></p>
		"
  end


  get '/templates' do
    templates = Dir["#{Dir.pwd}/templates/*"].map { |f| File.basename(f) }
    "#{templates.to_json}"
  end

  get '/job' do
    jid = MailWorker.perform_async
    { :job_id => jid }.to_json
  end

end
