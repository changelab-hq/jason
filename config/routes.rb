Jason::Engine.routes.draw do
  get '/api/config', to: 'api#configuration'
  post '/api/action', to: 'api#action'
  post '/api/create_subscription', to: 'api#create_subscription'
  post '/api/remove_subscription', to: 'api#remove_subscription'
  post '/api/get_payload', to: 'api#get_payload'
  post '/api/pusher/auth', to: 'api/pusher#auth'
end
