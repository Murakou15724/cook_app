class PasskeyRegistrationsController < ApplicationController
  before_action :authenticate_user!

  def options
    current_user.ensure_webauthn_id
    current_user.save! if current_user.webauthn_id_changed?

    options = WebAuthn::Credential.options_for_create(
      user: {
        id: current_user.webauthn_id,
        name: current_user.email,
        display_name: current_user.display_nickname
      },
      exclude: current_user.passkeys.pluck(:external_id),
      authenticator_selection: {
        resident_key: "preferred",
        user_verification: "preferred"
      }
    )

    session[:passkey_registration_challenge] = options.challenge
    render json: options
  end

  def create
    challenge = session.delete(:passkey_registration_challenge)
    return render_error("パスキー登録の有効期限が切れました。もう一度お試しください。") if challenge.blank?

    credential = WebAuthn::Credential.from_create(passkey_credential_params)
    credential.verify(challenge)

    current_user.passkeys.create!(
      external_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      nickname: params[:nickname].presence || passkey_nickname
    )

    render json: { message: "パスキーを登録しました" }
  rescue ActiveRecord::RecordInvalid
    render_error("このパスキーはすでに登録されています。")
  rescue WebAuthn::Error
    render_error("パスキーの登録に失敗しました。")
  end

  private

  def passkey_credential_params
    params.require(:credential).permit!.to_h
  end

  def passkey_nickname
    "パスキー #{Time.current.strftime('%Y/%m/%d %H:%M')}"
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_content
  end
end
