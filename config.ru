require './app/hydra.rb'

use Rack::Static,
 :urls => ["/css", "/img", "/js" ],
 :root => "public"

run Rack::URLMap.new('/' => App, '/sidekiq' => Sidekiq::Web)
