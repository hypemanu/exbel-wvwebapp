Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root 'readings#dashboard', as: :authenticated_root
  end
  
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :readings, only: [:index, :create, :new, :destroy] do
    collection do
      get 'dashboard'
    end
  end

  resources :groups, only: [:create]
  get 'my_group' => 'groups#my_group', as: :my_group

  get 'welcome' => "home#welcome"
  
  root 'home#welcome'
end
