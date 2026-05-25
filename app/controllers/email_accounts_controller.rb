class EmailAccountsController < ApplicationController
  before_action :authenticate_user!, except: [:callback]
  before_action :set_email_account, only: [:destroy]

  def index
    @email_accounts = current_user.email_accounts.order(:email)
  end

  def connect
    state = SecureRandom.hex(24)
    session[:gmail_oauth_state] = state
    session[:gmail_oauth_user_id] = current_user.id
    redirect_to Gmail::OauthService.authorize_url(state: state), allow_other_host: true
  end

  def callback
    if params[:error].present?
      redirect_to email_accounts_path, alert: t("email_accounts.connect.cancelled", error: params[:error])
      return
    end

    expected_state = session.delete(:gmail_oauth_state)
    user_id = session.delete(:gmail_oauth_user_id)

    if expected_state.blank? || params[:state] != expected_state || user_id.blank?
      redirect_to email_accounts_path, alert: t("email_accounts.connect.invalid_state")
      return
    end

    user = User.find_by(id: user_id)
    if user.nil? || (user_signed_in? && current_user != user)
      redirect_to email_accounts_path, alert: t("email_accounts.connect.invalid_state")
      return
    end

    sign_in(user) unless user_signed_in?

    data = Gmail::OauthService.exchange_code(params[:code])
    account = user.email_accounts.find_or_initialize_by(provider: "gmail", email: data[:email])

    account.access_token = data[:access_token]
    account.refresh_token = data[:refresh_token] if data[:refresh_token].present?
    account.token_expires_at = Time.current + data[:expires_in].seconds if data[:expires_in].positive?
    account.scopes = data[:scope]
    account.sync_status = "pending"
    account.save!

    redirect_to email_accounts_path, notice: t("email_accounts.connect.success", email: account.email)
  rescue Gmail::OauthService::OauthError => e
    Rails.logger.error("Gmail OAuth error: #{e.message}")
    redirect_to email_accounts_path, alert: t("email_accounts.connect.failed")
  end

  def destroy
    Gmail::OauthService.revoke!(@email_account.refresh_token.presence || @email_account.access_token)
    @email_account.destroy
    redirect_to email_accounts_path, notice: t("email_accounts.deleted")
  end

  private

  def set_email_account
    @email_account = current_user.email_accounts.find(params[:id])
  end
end
