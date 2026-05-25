class EmailAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  SYNC_STATUSES = %w[pending syncing ok error].freeze

  validates :email, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :provider, presence: true
  validates :sync_status, inclusion: { in: SYNC_STATUSES }

  scope :gmail, -> { where(provider: "gmail") }

  def token_expired?
    token_expires_at.nil? || token_expires_at <= Time.current
  end

  def mark_synced!(history_id: nil)
    update!(sync_status: "ok", last_synced_at: Time.current, history_id: history_id || self.history_id, last_sync_error: nil)
  end

  def mark_sync_error!(message)
    update!(sync_status: "error", last_sync_error: message.to_s.truncate(1000))
  end
end
