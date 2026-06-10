class CompaniesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company, only: [:show, :edit, :update, :destroy, :import_employees]

  def index
    @companies = Company.order(:name)
  end

  def summary
    companies = Company.order(:name).includes(:employees)
    exporter = Companies::SummaryPdfExporter.new(companies)
    send_data exporter.render, filename: exporter.filename,
              type: "application/pdf", disposition: "inline"
  end

  def show
    employees = @company.employees.includes(:contracts)

    if params[:q].present?
      term = "%#{params[:q].downcase}%"
      employees = employees.where(
        "LOWER(first_surname) LIKE :t OR LOWER(COALESCE(second_surname,'')) LIKE :t OR LOWER(first_name) LIKE :t OR LOWER(COALESCE(other_names,'')) LIKE :t OR document_number LIKE :d",
        t: term, d: "%#{params[:q]}%"
      )
    end

    active_ids = Contract.where(status: "active").select(:employee_id)
    case params[:status]
    when "active"
      employees = employees.where(id: active_ids)
    when "inactive"
      employees = employees.where.not(id: active_ids)
    end

    if params[:job_profile_id].present?
      profiled_ids = Contract.where(job_profile_id: params[:job_profile_id]).select(:employee_id)
      employees = employees.where(id: profiled_ids)
    end

    employees = employees.order(:first_surname, :first_name)
    @job_profiles = @company.job_profiles.order(:name)
    @pagy, @employees = pagy(employees, limit: 20)
  end

  def new
    @company = Company.new
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      redirect_to @company, notice: t("companies.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @company.update(company_params)
      redirect_to @company, notice: t("companies.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy
    redirect_to companies_path, notice: t("companies.deleted")
  end

  def import_employees
    if params[:file].blank?
      redirect_to @company, alert: t("companies.import.no_file")
      return
    end

    parser = Converters::SyscafeDirectoryParser.new(params[:file].tempfile.path)
    parser.parse

    if parser.entries.empty?
      redirect_to @company, alert: t("companies.import.no_employees")
      return
    end

    employees_created = 0
    employees_updated = 0
    contracts_created = 0
    contracts_updated = 0
    errors = []

    parser.entries.each do |entry|
      emp_data = entry[:employee].compact
      contract_data = entry[:contract].compact

      employee = @company.employees.find_or_initialize_by(document_number: emp_data[:document_number])
      emp_was_new = employee.new_record?

      # Always update personal data with the latest row
      employee.assign_attributes(emp_data)

      unless employee.save
        errors << "#{emp_data[:document_number]}: #{employee.errors.full_messages.join(', ')}"
        next
      end

      emp_was_new ? employees_created += 1 : employees_updated += 1

      # Create or update contract by contract_number
      if contract_data[:contract_number].present?
        contract = employee.contracts.find_or_initialize_by(contract_number: contract_data[:contract_number])
      else
        contract = employee.contracts.find_or_initialize_by(contract_date: contract_data[:contract_date])
      end

      contract_was_new = contract.new_record?
      contract.assign_attributes(contract_data)

      if contract.save
        contract_was_new ? contracts_created += 1 : contracts_updated += 1
      else
        errors << "#{emp_data[:document_number]} contrato: #{contract.errors.full_messages.join(', ')}"
      end
    end

    message = t("companies.import.success",
      employees_created: employees_created,
      employees_updated: employees_updated,
      contracts_created: contracts_created,
      contracts_updated: contracts_updated)
    message += " #{t('companies.import.errors', count: errors.size)}" if errors.any?

    redirect_to @company, notice: message
  rescue StandardError => e
    Rails.logger.error("Import error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    redirect_to @company, alert: t("companies.import.failed")
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:name, :nit, :payroll_prefix, :payroll_code, :last_payroll_consecutive)
  end
end
