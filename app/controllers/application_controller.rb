class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    return if logged_in?

    redirect_to login_path, alert: "ログインしてください"
  end

  def require_no_login!
    redirect_to root_path if logged_in?
  end
end
