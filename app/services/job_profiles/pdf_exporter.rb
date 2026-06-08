require "prawn"
require "prawn/table"

module JobProfiles
  # Renders a job profile (with its company header, all fields and the risk
  # matrix) into a printable PDF using Prawn (pure Ruby, no system binaries).
  class PdfExporter
    PROFILE_FIELDS = [
      :education, :training, :experience, :authority, :skills,
      :position_objectives, :hse_objectives, :main_responsibility
    ].freeze

    GRAY = "555555".freeze
    LINE = "DDDDDD".freeze

    def initialize(company, job_profile)
      @company = company
      @profile = job_profile
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])
      header
      identification
      profile_block
      functions_block
      risks_block
      metadata
      footer
      @pdf.render
    end

    def filename
      base = "Perfil_#{@profile.name}_#{@company.name}".parameterize(separator: "_")
      "#{base}.pdf"
    end

    private

    def header
      @pdf.fill_color GRAY
      @pdf.text safe(@company.name), size: 13, style: :bold
      @pdf.text "#{t('companies.fields.nit')}: #{safe(@company.nit)}", size: 9
      @pdf.fill_color "000000"
      @pdf.move_down 6
      meta = [@profile.form_code, @profile.form_version && "v#{@profile.form_version}",
              @profile.form_date && I18n.l(@profile.form_date, format: :short)].compact.join("  ·  ")
      @pdf.text safe(meta), size: 8, color: GRAY unless meta.blank?
      @pdf.move_down 10
      @pdf.text safe(@profile.name), size: 18, style: :bold
      @pdf.text "#{t('job_profiles.fields.code')}: #{safe(@profile.code)}", size: 9, color: GRAY if @profile.code.present?
      divider
    end

    def identification
      section_title(t("job_profiles.form.identification"))
      field(:immediate_boss, @profile.immediate_boss)
      field(:people_in_charge, @profile.people_in_charge)
    end

    def profile_block
      section_title(t("job_profiles.form.profile"))
      PROFILE_FIELDS.each { |attr| field(attr, @profile.public_send(attr)) }
    end

    def functions_block
      return if @profile.own_functions.blank? && @profile.sig_responsibilities.blank?

      section_title(t("job_profiles.form.functions"))
      field(:own_functions, @profile.own_functions)
      field(:sig_responsibilities, @profile.sig_responsibilities)
    end

    def risks_block
      return if @profile.risks.empty?

      section_title(t("job_profiles.form.risks"))
      @profile.risks.group_by(&:category).each do |category, risks|
        @pdf.move_down 2
        @pdf.text safe(t("job_profiles.risk_categories.#{JobProfileRisk::CATEGORIES[category]}")),
                  size: 9, style: :bold, color: GRAY
        rows = risks.map { |r| [safe(r.factor), r.exposure_label || t("job_profiles.risk_table.none")] }
        @pdf.table(rows, width: @pdf.bounds.width, cell_style: { size: 9, padding: [3, 6], borders: [:bottom], border_color: LINE }) do
          column(1).style(align: :right, width: 90)
        end
        @pdf.move_down 6
      end
    end

    def metadata
      pairs = [
        [t("job_profiles.fields.elaborated_by"), @profile.elaborated_by],
        [t("job_profiles.fields.approved_by"), @profile.approved_by]
      ].reject { |_, v| v.blank? }
      return if pairs.empty?

      divider
      pairs.each { |label, value| @pdf.text "#{safe(label)}: #{safe(value)}", size: 9, color: GRAY }
    end

    def footer
      @pdf.number_pages "<page>/<total>", at: [@pdf.bounds.right - 50, -10], size: 8, color: GRAY
    end

    # --- helpers ---

    def section_title(text)
      @pdf.move_down 8
      @pdf.text safe(text), size: 12, style: :bold
      @pdf.move_down 4
    end

    def field(attr, value)
      return if value.blank?

      label = attr.is_a?(Symbol) ? t("job_profiles.fields.#{attr}") : attr
      @pdf.formatted_text(
        [{ text: "#{safe(label)}: ", styles: [:bold] }, { text: safe(value) }],
        size: 10, leading: 2
      )
      @pdf.move_down 5
    end

    def divider
      @pdf.move_down 6
      @pdf.stroke_color LINE
      @pdf.stroke_horizontal_rule
      @pdf.stroke_color "000000"
      @pdf.move_down 8
    end

    def t(key)
      I18n.t(key)
    end

    # Prawn's built-in fonts only cover Windows-1252; drop/normalize anything else
    # so Spanish text renders without raising encoding errors.
    def safe(value)
      value.to_s
           .gsub(/[‘’]/, "'")
           .gsub(/[“”]/, '"')
           .gsub(/[–—]/, "-")
           .gsub(/•/, "-")
           .gsub(/ /, " ")
           .encode("Windows-1252", invalid: :replace, undef: :replace, replace: "")
           .encode("UTF-8")
    end
  end
end
