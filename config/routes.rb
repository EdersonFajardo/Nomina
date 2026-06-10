Rails.application.routes.draw do
  devise_for :users, path: "auth"

  get "up" => "rails/health#show", as: :rails_health_check

  resources :users, except: [:show]
  resources :companies do
    collection do
      get :summary
    end
    member do
      post :import_employees
    end
    resources :employees
    resources :job_profiles do
      collection do
        post :import
        post :assign_to_contracts
        get :manual_assignments
        patch :bulk_assign
      end
    end
  end
  resources :employees, only: [:index, :show, :edit, :update]
  resources :documents, only: [:index] do
    collection do
      post :convert
    end
  end
  resources :conversion_logs, only: [:index]
  resources :payroll_archives, only: [:index]
  resources :period_reports, only: [:index]

  resources :email_accounts, only: [:index, :destroy] do
    collection do
      get :connect
    end
  end
  get "/auth/google_oauth2/callback", to: "email_accounts#callback"

  root "dashboard#index"
end
