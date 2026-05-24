import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "status"]
  static values = {
    loginOptionsUrl: String,
    loginUrl: String,
    registrationOptionsUrl: String,
    registrationUrl: String
  }

  async login() {
    if (!this.supported()) return

    try {
      this.setStatus("パスキーを確認しています。")
      const options = await this.postJson(this.loginOptionsUrlValue, { email: this.emailValue() })
      const credential = await navigator.credentials.get({
        publicKey: this.decodePublicKeyOptions(options)
      })
      const result = await this.postJson(this.loginUrlValue, {
        credential: this.serializeCredential(credential)
      })

      window.location.href = result.redirect_url
    } catch (error) {
      this.setStatus(error.message || "パスキーログインに失敗しました。")
    }
  }

  async register() {
    if (!this.supported()) return

    try {
      this.setStatus("パスキーを登録しています。")
      const options = await this.postJson(this.registrationOptionsUrlValue)
      const credential = await navigator.credentials.create({
        publicKey: this.decodePublicKeyOptions(options)
      })
      const result = await this.postJson(this.registrationUrlValue, {
        credential: this.serializeCredential(credential)
      })

      this.setStatus(result.message || "パスキーを登録しました。")
    } catch (error) {
      this.setStatus(error.message || "パスキーの登録に失敗しました。")
    }
  }

  supported() {
    if (window.PublicKeyCredential && navigator.credentials) return true

    this.setStatus("このブラウザはパスキーに対応していません。通常ログインをご利用ください。")
    return false
  }

  emailValue() {
    return this.hasEmailTarget ? this.emailTarget.value : ""
  }

  async postJson(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body)
    })
    const json = await response.json()

    if (!response.ok) throw new Error(json.error || "通信に失敗しました。")
    return json
  }

  decodePublicKeyOptions(options) {
    const publicKey = { ...options }
    publicKey.challenge = this.base64urlToBuffer(publicKey.challenge)

    if (publicKey.user?.id) {
      publicKey.user = { ...publicKey.user, id: this.base64urlToBuffer(publicKey.user.id) }
    }

    if (publicKey.excludeCredentials) {
      publicKey.excludeCredentials = publicKey.excludeCredentials.map((credential) => ({
        ...credential,
        id: this.base64urlToBuffer(credential.id)
      }))
    }

    if (publicKey.allowCredentials) {
      publicKey.allowCredentials = publicKey.allowCredentials.map((credential) => ({
        ...credential,
        id: this.base64urlToBuffer(credential.id)
      }))
    }

    return publicKey
  }

  serializeCredential(credential) {
    const response = credential.response
    const serialized = {
      id: credential.id,
      type: credential.type,
      rawId: this.bufferToBase64url(credential.rawId),
      clientExtensionResults: credential.getClientExtensionResults(),
      response: {
        clientDataJSON: this.bufferToBase64url(response.clientDataJSON)
      }
    }

    if (response.attestationObject) {
      serialized.response.attestationObject = this.bufferToBase64url(response.attestationObject)
    }

    if (response.authenticatorData) {
      serialized.response.authenticatorData = this.bufferToBase64url(response.authenticatorData)
      serialized.response.signature = this.bufferToBase64url(response.signature)
      serialized.response.userHandle = response.userHandle ? this.bufferToBase64url(response.userHandle) : null
    }

    return serialized
  }

  base64urlToBuffer(value) {
    const base64 = value.replace(/-/g, "+").replace(/_/g, "/")
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=")
    const binary = atob(padded)
    const bytes = new Uint8Array(binary.length)

    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i)
    }

    return bytes.buffer
  }

  bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""

    bytes.forEach((byte) => {
      binary += String.fromCharCode(byte)
    })

    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
