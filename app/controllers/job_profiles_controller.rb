class JobProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company
  before_action :set_job_profile, only: [:show, :edit, :update, :destroy]

  def index
    profiles = @company.job_profiles.search(params[:q]).ordered
    @pagy, @job_profiles = pagy(profiles, limit: 20)
  end

  def show
    @contracts = @job_profile.contracts
                             .joins(:employee)
                             .includes(:employee)
                             .order("employees.first_surname, employees.first_name")

    respond_to do |format|
      format.html
      format.pdf do
        exporter = JobProfiles::PdfExporter.new(@company, @job_profile)
        send_data exporter.render, filename: exporter.filename,
                  type: "application/pdf", disposition: "inline"
      end
    end
  end

  def new
    @job_profile = @company.job_profiles.build
    @job_profile.build_default_risks
  end

  def create
    @job_profile = @company.job_profiles.build(job_profile_params)

    if @job_profile.save
      redirect_to [@company, @job_profile], notice: t("job_profiles.created")
    else
      @job_profile.build_default_risks if @job_profile.risks.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @job_profile.build_default_risks if @job_profile.risks.empty?
  end

  def update
    if @job_profile.update(job_profile_params)
      redirect_to [@company, @job_profile], notice: t("job_profiles.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job_profile.destroy
    redirect_to company_job_profiles_path(@company), notice: t("job_profiles.deleted")
  end

  def import
    if params[:file].blank?
      redirect_to company_job_profiles_path(@company), alert: t("job_profiles.import.no_file")
      return
    end

    parser = Converters::JobProfilesParser.new(params[:file].tempfile.path)
    parser.parse

    if parser.profiles.empty?
      redirect_to company_job_profiles_path(@company), alert: t("job_profiles.import.none_found")
      return
    end

    created = 0
    updated = 0
    errors = []

    parser.profiles.each do |attrs|
      risks = attrs.delete(:risks) || []
      profile = @company.job_profiles.find_or_initialize_by(name: attrs[:name])
      was_new = profile.new_record?

      profile.assign_attributes(attrs)
      profile.risks.destroy_all if profile.persisted?
      risks.each { |risk| profile.risks.build(risk) }

      if profile.save
        was_new ? created += 1 : updated += 1
      else
        errors << "#{attrs[:name]}: #{profile.errors.full_messages.join(', ')}"
      end
    end

    message = t("job_profiles.import.success", created: created, updated: updated)
    message += " #{t('job_profiles.import.errors', count: errors.size)}" if errors.any?
    redirect_to company_job_profiles_path(@company), notice: message
  rescue Zip::Error, ArgumentError, IOError => e
    Rails.logger.error("Job profiles import - invalid file: #{e.message}")
    redirect_to company_job_profiles_path(@company), alert: t("job_profiles.import.invalid_file")
  rescue StandardError => e
    Rails.logger.error("Job profiles import error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    redirect_to company_job_profiles_path(@company), alert: t("job_profiles.import.failed")
  end

  def assign_to_contracts
    result = JobProfiles::ContractMatcher.new(@company).match_all!
    redirect_to company_job_profiles_path(@company),
                notice: t("job_profiles.assign.success", matched: result.matched, unmatched: result.unmatched)
  end

  def manual_assignments
    @profiles = @company.job_profiles.ordered
    @contracts = unassigned_contracts.includes(:employee, :job_profile)
                                     .order("employees.first_surname, employees.first_name")
  end

  def bulk_assign
    assignments = params.fetch(:assignments, {})
    valid_profile_ids = @company.job_profiles.pluck(:id).to_set
    updated = 0

    assignments.each do |contract_id, profile_id|
      next if profile_id.blank?
      next unless valid_profile_ids.include?(profile_id.to_i)

      contract = unassigned_contracts.find_by(id: contract_id)
      next unless contract

      contract.update(job_profile_id: profile_id)
      updated += 1
    end

    redirect_to company_job_profiles_path(@company),
                notice: t("job_profiles.manual.success", count: updated)
  end

  private

  def unassigned_contracts
    Contract.joins(:employee)
            .where(employees: { company_id: @company.id }, job_profile_id: nil)
  end

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_job_profile
    @job_profile = @company.job_profiles.find(params[:id])
  end

  def job_profile_params
    params.require(:job_profile).permit(
      :name, :code, :immediate_boss, :people_in_charge,
      :education, :training, :experience, :authority, :skills,
      :position_objectives, :hse_objectives, :main_responsibility,
      :own_functions, :sig_responsibilities,
      :elaborated_by, :approved_by, :form_code, :form_version, :form_date,
      risks_attributes: [:id, :category, :factor, :exposure_level, :position, :_destroy]
    )
  end
end
