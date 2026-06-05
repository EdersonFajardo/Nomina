class Company < ApplicationRecord
  has_many :employees, dependent: :destroy
  has_many :job_profiles, dependent: :destroy

  validates :name, presence: true
  validates :nit, presence: true, uniqueness: true

  def next_payroll_consecutive(count)
    start = last_payroll_consecutive + 1
    update!(last_payroll_consecutive: last_payroll_consecutive + count)
    start
  end

  def payroll_prefix_or_default
    payroll_prefix.presence || "NM"
  end

  def payroll_code_or_default
    payroll_code.presence || name.to_s.split(/\s+/).first.to_s.upcase
  end
end
