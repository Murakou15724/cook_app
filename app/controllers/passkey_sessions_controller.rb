class PasskeySessionsController < ApplicationController
  before_action :require_no_login!, only: [:options, :create]

  def options
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    allow = user&.passkeys&.pluck(:external_id)

    options = if allow.present?
                WebAuthn::Credential.options_for_get(
                  allow: allow,
                  user_verification: "preferred"
                )
              else
                WebAuthn::Credential.options_for_get(user_verification: "preferred")
              end

    session[:passkey_authentication_challenge] = options.challenge
    render json: options
  end

  def create
    challenge = session.delete(:passkey_authentication_challenge)
    return render_error("パスキーログインの有効期限が切れました。もう一度お試しください。") if challenge.blank?

    credential = WebAuthn::Credential.from_get(passkey_credential_params)
    passkey = Passkey.find_by(external_id: credential.id)
    return render_error("登録済みのパスキーが見つかりません。") unless passkey

    credential.verify(
      challenge,
      public_key: passkey.public_key,
      sign_count: passkey.sign_count
    )

    passkey.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    session[:user_id] = passkey.user_id

    render json: { message: "ログインしました", redirect_url: root_path }
  rescue WebAuthn::SignCountVerificationError
    render_error("パスキーの検証に失敗しました。別のログイン方法をお試しください。")
  rescue WebAuthn::Error
    render_error("パスキーログインに失敗しました。")
  end

  private

  def passkey_credential_params
    params.require(:credential).permit!.to_h
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
