require "net/http"
require "json"

module Gmail
  class OauthService
    class OauthError < StandardError; end

    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo".freeze
    REVOKE_URL = "https://oauth2.googleapis.com/revoke".freeze

    SCOPES = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.readonly",
      "https://www.googleapis.com/auth/gmail.send",
      "https://www.googleapis.com/auth/gmail.modify"
    ].freeze

    class << self
      def authorize_url(state:)
        params = {
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          scope: SCOPES.join(" "),
          access_type: "offline",
          include_granted_scopes: "true",
          prompt: "consent",
          state: state
        }
        "#{AUTHORIZE_URL}?#{URI.encode_www_form(params)}"
      end

      def exchange_code(code)
        response = post_form(TOKEN_URL, {
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri,
          grant_type: "authorization_code"
        })

        access_token = response["access_token"]
        raise OauthError, "Missing access_token in token response" if access_token.blank?

        userinfo = fetch_userinfo(access_token)

        {
          email: userinfo["email"],
          access_token: access_token,
          refresh_token: response["refresh_token"],
          expires_in: response["expires_in"].to_i,
          scope: response["scope"]
        }
      end

      def refresh_token!(account)
        return account if account.refresh_token.blank?

        response = post_form(TOKEN_URL, {
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: account.refresh_token,
          grant_type: "refresh_token"
        })

        account.update!(
          access_token: response["access_token"],
          token_expires_at: Time.current + response["expires_in"].to_i.seconds
        )
        account
      end

      def revoke!(token)
        return if token.blank?
        post_form(REVOKE_URL, { token: token })
      rescue OauthError
        # Best-effort: ignore failures so we can still delete locally
        nil
      end

      def client_id
        ENV.fetch("GOOGLE_OAUTH_CLIENT_ID")
      end

      def client_secret
        ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET")
      end

      def redirect_uri
        ENV.fetch("GOOGLE_OAUTH_REDIRECT_URI")
      end

      private

      def fetch_userinfo(access_token)
        uri = URI(USERINFO_URL)
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{access_token}"
        res = http(uri).request(req)
        raise OauthError, "userinfo failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      end

      def post_form(url, params)
        uri = URI(url)
        res = http(uri).post(uri.path, URI.encode_www_form(params), { "Content-Type" => "application/x-www-form-urlencoded" })
        raise OauthError, "#{url} failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      end

      def http(uri)
        Net::HTTP.new(uri.host, uri.port).tap { |h| h.use_ssl = true }
      end
    end
  end
end
