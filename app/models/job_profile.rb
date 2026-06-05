class JobProfile < ApplicationRecord
  belongs_to :company
  has_many :risks, -> { order(:position) },
           class_name: "JobProfileRisk", dependent: :destroy, inverse_of: :job_profile
  has_many :contracts, dependent: :nullify

  accepts_nested_attributes_for :risks, allow_destroy: true

  validates :name, presence: true,
                   uniqueness: { scope: :company_id, case_sensitive: false }

  scope :ordered, -> { order(:name) }

  scope :search, ->(term) {
    next all if term.blank?
    pattern = "%#{term.downcase}%"
    where("LOWER(name) LIKE :p OR LOWER(COALESCE(code, '')) LIKE :p OR " \
          "LOWER(COALESCE(immediate_boss, '')) LIKE :p", p: pattern)
  }

  # Build the standard risk-factor catalog as unsaved associated records,
  # so new profiles and the form start with the full INGECOL matrix.
  def build_default_risks
    JobProfileRisk::DEFAULT_FACTORS.each_with_index do |(category, factor), index|
      risks.build(category: category, factor: factor, position: index)
    end
  end

  def assigned_contracts_count
    contracts.size
  end
end
