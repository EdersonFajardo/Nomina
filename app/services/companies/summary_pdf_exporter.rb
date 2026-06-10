require "prawn"
require "prawn/table"

module Companies
  # Renders a summary PDF of all companies: each company's name, NIT and code,
  # followed by a table of its currently active employees (name + document).
  # Pure Ruby via Prawn (no system binaries).
  class SummaryPdfExporter
    GRAY = "555555".freeze
    LINE = "DDDDDD".freeze
    HEADER_BG = "F3F4F6".freeze

    def initialize(companies)
      @companies = companies
    end

    def render
      @pdf = Prawn::Document.new(page_size: "A4", margin: [40, 40, 40, 40])
      title
      @companies.each_with_index do |company, index|
        @pdf.start_new_page if index.positive?
        company_block(company)
      end
      footer
      @pdf.render
    end

    def filename
      "Resumen_Empresas_#{Date.current.strftime('%Y-%m-%d')}.pdf"
    end

    private

    def title
      @pdf.text safe(t("companies.summary_export.title")), size: 18, style: :bold
      @pdf.text "#{t('companies.summary_export.generated_at')}: #{I18n.l(Time.current, format: :long)}",
                size: 9, color: GRAY
      divider
    end

    def company_block(company)
      employees = active_employees(company)

      @pdf.fill_color "000000"
      @pdf.text safe(company.name), size: 14, style: :bold
      meta = [
        "#{t('companies.fields.nit')}: #{safe(company.nit)}",
        "#{t('companies.fields.payroll_code')}: #{safe(company.payroll_code_or_default)}",
        "#{t('companies.summary_export.active_count')}: #{employees.size}"
      ].join("    ·    ")
      @pdf.move_down 2
      @pdf.text safe(meta), size: 9, color: GRAY
      @pdf.move_down 8

      if employees.empty?
        @pdf.text safe(t("companies.summary_export.no_active")), size: 9, style: :italic, color: GRAY
        return
      end

      header_row = [
        t("companies.summary_export.employee_name"),
        t("companies.summary_export.employee_document"),
        t("companies.summary_export.employee_phone"),
        t("companies.summary_export.employee_email")
      ]
      rows = employees.map do |e|
        [
          safe(e.full_name),
          safe(e.document_number),
          safe(e.mobile.presence || e.phone.presence || not_available),
          safe(e.email.presence || not_available)
        ]
      end

      @pdf.table([header_row] + rows, width: @pdf.bounds.width,
                 header: true,
                 cell_style: { size: 8, padding: [4, 6], borders: [:bottom], border_color: LINE }) do
        row(0).style(font_style: :bold, background_color: HEADER_BG)
        column(1).style(width: 80)
        column(2).style(width: 80)
      end
    end

    # Employees with at least one active contract, ordered by surname/name.
    def active_employees(company)
      active_ids = Contract.where(status: "active").select(:employee_id)
      company.employees.where(id: active_ids).order(:first_surname, :first_name)
    end

    def divider
      @pdf.move_down 6
      @pdf.stroke_color LINE
      @pdf.stroke_horizontal_rule
      @pdf.stroke_color "000000"
      @pdf.move_down 8
    end

    def footer
      @pdf.number_pages "<page>/<total>", at: [@pdf.bounds.right - 50, -10], size: 8, color: GRAY
    end

    def not_available
      t("companies.summary_export.not_available")
    end

    def t(key)
      I18n.t(key)
    end

    # Prawn's built-in fonts only cover Windows-1252; normalize anything else
    # so Spanish text renders without raising encoding errors.
    def safe(value)
      value.to_s
           .gsub(/[‘’]/, "'")
           .gsub(/[“”]/, '"')
           .gsub(/[–—]/, "-")
           .gsub(/•/, "-")
           .gsub(/ /, " ")
           .encode("Windows-1252", invalid: :replace, undef: :replace, replace: "")
           .encode("UTF-8")
    end
  end
end
