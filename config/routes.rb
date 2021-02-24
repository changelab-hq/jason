Jason::Engine.routes.draw do
  get '/api/config', to: 'jason#configuration'
  post '/api/action', to: 'jason#action'
  post '/api/create_subscription', to: 'jason#create_subscription'
  post '/api/remove_subscription', to: 'jason#remove_subscription'
  post '/api/get_payload', to: 'jason#get_payload'
  post '/api/pusher/auth', to: 'pusher#auth'
end
