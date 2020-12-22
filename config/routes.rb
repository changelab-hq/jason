Jason::Engine.routes.draw do
  get '/api/schema', to: 'api#schema'
  post '/api/action', to: 'api#action'
end
