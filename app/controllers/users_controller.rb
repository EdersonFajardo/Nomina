class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:edit, :update, :destroy]

  def index
    @users = User.order(:email)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: t("users.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if user_params[:password].blank?
      attrs = user_params.except(:password, :password_confirmation)
    else
      attrs = user_params
    end

    if @user.update(attrs)
      redirect_to users_path, notice: t("users.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: t("users.cannot_delete_self")
    else
      @user.destroy
      redirect_to users_path, notice: t("users.deleted")
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
