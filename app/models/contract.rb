class Contract < ApplicationRecord
  belongs_to :employee
  belongs_to :job_profile, optional: true

  CONTRACT_TYPES = {
    1 => "Termino fijo",
    2 => "Termino indefinido",
    3 => "Obra o labor",
    4 => "Aprendizaje",
    5 => "Practicas"
  }.freeze

  validates :contract_type, presence: true, inclusion: { in: CONTRACT_TYPES.keys }
  validates :contract_number, uniqueness: { scope: :employee_id }, allow_blank: true

  scope :active, -> { where(status: "active") }
  scope :latest, -> { order(contract_date: :desc) }

  def self.vigente_en(period_start, period_end)
    where("contract_date <= ?", period_end)
      .where("contract_end_date IS NULL OR contract_end_date >= ?", period_start)
      .order(contract_date: :desc)
      .first
  end

  def contract_type_label
    CONTRACT_TYPES[contract_type] || contract_type.to_s
  end

  def status_label
    status == "active" ? "Activo" : "Inactivo"
  end

  def active?
    status == "active"
  end
end
