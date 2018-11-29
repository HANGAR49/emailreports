web: bundle exec rackup config.ru -p $PORT
worker: bundle exec sidekiq -r ./workers/mail_worker.rb 
