Rails.application.routes.draw do
  get 'add', to: 'add#index'
  get 'ping', to: 'ping#index'
end
