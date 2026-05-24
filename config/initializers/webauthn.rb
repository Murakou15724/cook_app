WebAuthn.configure do |config|
  default_origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000"
  ]

  config.allowed_origins = ENV.fetch("WEBAUTHN_ALLOWED_ORIGINS", default_origins.join(",")).split(",").map(&:strip)
  config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", "localhost")
  config.rp_name = "料理アプリ"
end
