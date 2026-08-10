class ProfilesController < ApplicationController
  before_action :set_user
  before_action :verify_current_password, except: :show
  rate_limit to: 10, within: 3.minutes, only: %i[ update update_password destroy ],
    with: -> { redirect_to profile_path, alert: "Try again later." }

  def show
  end

  def update
    if @user.update(params.expect(user: [ :username ]))
      redirect_to profile_path, notice: "Profile updated."
    else
      @section = :profile
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    if @user.update(params.expect(user: [ :password, :password_confirmation ]))
      @user.sessions.destroy_all
      start_new_session_for @user
      redirect_to profile_path, notice: "Password updated."
    else
      @section = :password
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    # Not terminate_session: the session row is already gone with the user.
    Current.session = nil
    cookies.delete(:session_id)
    redirect_to new_session_path, status: :see_other, notice: "Your account has been deleted."
  end

  private
    def set_user
      @user = Current.user
    end

    def verify_current_password
      redirect_to profile_path, alert: "Current password is incorrect." unless @user.authenticate(params[:current_password])
    end
end
