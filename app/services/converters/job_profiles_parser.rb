module Converters
  # Parses the RH-F-14 "Perfiles de Cargo" workbook. Each sheet whose A1 equals
  # "PERFIL DE CARGOS" is one job profile. The layout is irregular: field labels
  # are embedded as inline prefixes in column A and rows shift between sheets, so
  # we locate values by matching the label text rather than by fixed coordinates.
  class JobProfilesParser
    attr_reader :profiles

    MAX_ROW = 80
    PROFILE_MARKER = "PERFIL DE CARGOS".freeze

    # field => label variants (normalized: accent-free, uppercase)
    LABELS = {
      immediate_boss: ["JEFE INMEDIATO"],
      people_in_charge: ["PERSONAS A CARGO"],
      education: ["EDUCACION"],
      training: ["FORMACION"],
      experience: ["EXPERIENCIA"],
      authority: ["AUTORIDAD"],
      skills: ["HABILIDADES"],
      position_objectives: ["OBJETIVOS DEL CARGO"],
      hse_objectives: ["OBJETIVOS EN HSE", "OBJETIVOS HSE"],
      main_responsibility: ["RESPONSABILIDAD PRINCIPAL"]
    }.freeze

    # [category, canonical factor (matches JobProfileRisk::DEFAULT_FACTORS), keywords]
    RISK_FACTORS = [
      [1, "Iluminación", ["iluminacion"]],
      [1, "Energía mecánica (Ruido)", ["energia mecanica", "ruido"]],
      [1, "Energía térmica (frío, calor)", ["energia term"]],
      [2, "Contaminación por sustancias tóxicas", ["contaminacion", "sustancias toxic"]],
      [2, "Pegantes, jabones, productos químicos", ["pegantes", "jabones"]],
      [3, "Contenido de labores de trabajo", ["contenido de labores"]],
      [3, "Organización del tiempo", ["organizacion del tiempo"]],
      [3, "Relaciones humanas", ["relaciones humanas"]],
      [3, "Gestión", ["gestion"]],
      [4, "Carga estática (pie, sentado, etc)", ["carga estatica"]],
      [4, "Carga dinámica", ["carga dinamica"]],
      [5, "Herramientas", ["herramientas"]],
      [5, "Maquinaria", ["maquinaria"]],
      [5, "Mecanismos en movimiento", ["mecanismos"]]
    ].freeze

    def initialize(file)
      @file = file
      @profiles = []
    end

    def parse
      spreadsheet = Roo::Spreadsheet.open(@file)
      spreadsheet.sheets.each do |sheet_name|
        sheet = spreadsheet.sheet(sheet_name)
        next unless profile_sheet?(sheet)

        @profiles << parse_sheet(sheet, sheet_name)
      end
      self
    end

    private

    def profile_sheet?(sheet)
      norm(txt(sheet, 1, 1)).include?(PROFILE_MARKER)
    end

    def parse_sheet(sheet, sheet_name)
      data = { name: profile_name(sheet, sheet_name), code: code_from_title(sheet_name) }

      LABELS.each do |field, variants|
        data[field] = find_labelled_value(sheet, variants)
      end

      own, sig = extract_functions(sheet)
      data[:own_functions] = own
      data[:sig_responsibilities] = sig

      data.merge!(extract_metadata(sheet))
      data[:risks] = extract_risks(sheet)
      data.compact
    end

    def profile_name(sheet, sheet_name)
      a5 = txt(sheet, 5, 1).strip
      if a5.present? && !looks_like_label?(a5)
        squish(a5)
      else
        name_from_title(sheet_name)
      end
    end

    def looks_like_label?(text)
      n = norm(text)
      LABELS.values.flatten.any? { |label| n.start_with?(label) } ||
        n.start_with?("NO. DE")
    end

    def code_from_title(sheet_name)
      sheet_name.to_s[/\A\s*(\d+)/, 1]
    end

    def name_from_title(sheet_name)
      squish(sheet_name.to_s.sub(/\A\s*\d+\s*[-.\)]*\s*/, "")).upcase
    end

    # Finds the first column-A cell containing one of the label variants and
    # returns the text that follows the label.
    def find_labelled_value(sheet, variants)
      (1..MAX_ROW).each do |row|
        raw = txt(sheet, row, 1)
        next if raw.blank?

        n = norm(raw)
        variants.each do |label|
          idx = n.index(label)
          next unless idx && idx <= 10

          value = raw[(idx + label.length)..].to_s.sub(/\A[\s:.\-]+/, "").strip
          return value.presence
        end
      end
      nil
    end

    # Functions live below the header until the risk section. The layout varies:
    # some sheets pack every function into a single multiline cell, others use one
    # row per function. Collecting every non-empty cell in the range handles both.
    # Column A = own functions, column B = SIG responsibilities.
    def extract_functions(sheet)
      header = (1..MAX_ROW).find do |row|
        norm(txt(sheet, row, 1)).include?("FUNCIONES Y RESPONSABILIDADES PROPIAS")
      end
      return [nil, nil] unless header

      stop = ((header + 1)..MAX_ROW).find do |row|
        norm(txt(sheet, row, 1)).include?("CONDICIONES Y RIESGOS")
      end || (header + 20)

      own_lines = []
      sig_lines = []
      ((header + 1)...stop).each do |row|
        a = txt(sheet, row, 1).strip
        b = txt(sheet, row, 2).strip
        own_lines << a if a.present? && !section_header?(a)
        sig_lines << b if b.present? && !section_header?(b)
      end

      [own_lines.join("\n").presence, sig_lines.join("\n").presence]
    end

    # Stray section headers (e.g. "RESPONSABILIDADES CON EL SGI") sometimes sit
    # inside the functions range and must not be captured as content.
    def section_header?(text)
      n = norm(text)
      n.include?("RESPONSABILIDADES CON EL S") ||
        n.include?("FUNCIONES Y RESPONSABILIDADES PROPIAS")
    end

    def extract_metadata(sheet)
      meta = {}
      # Header block: D1/E1 = Código, D2/E2 = Versión, D3/E3 = Fecha
      meta[:form_code] = txt(sheet, 1, 5).strip.presence || "RH-F-14"
      meta[:form_version] = txt(sheet, 2, 5).strip.presence
      date_cell = sheet.cell(3, 5)
      meta[:form_date] = date_cell.is_a?(Date) ? date_cell : nil
      meta[:elaborated_by] = find_labelled_value(sheet, ["ELABORADO POR"])
      meta[:approved_by] = find_labelled_value(sheet, ["APROBADO POR"])
      meta.compact
    end

    def extract_risks(sheet)
      start = (1..MAX_ROW).find do |row|
        norm(txt(sheet, row, 1)).include?("CONDICIONES Y RIESGOS")
      end || 1

      RISK_FACTORS.each_with_index.map do |(category, factor, keywords), index|
        row = (start..MAX_ROW).find do |r|
          a = norm(txt(sheet, r, 1))
          a.present? && keywords.any? { |kw| a.include?(norm(kw)) }
        end

        { category: category, factor: factor, position: index,
          exposure_level: row ? exposure_at(sheet, row) : nil }
      end
    end

    # Columns B..E (2..5) mark the exposure grade with an "X".
    def exposure_at(sheet, row)
      (2..5).each do |col|
        return col - 1 if norm(txt(sheet, row, col)) == "X"
      end
      nil
    end

    def txt(sheet, row, col)
      strip_html(sheet.cell(row, col).to_s)
    rescue StandardError
      ""
    end

    # Roo returns rich-text cells as HTML markup (e.g. "<html><b>...</b></html>").
    def strip_html(value)
      return value unless value.include?("<")

      value.gsub(/<[^>]+>/, "")
           .gsub("&amp;", "&").gsub("&lt;", "<").gsub("&gt;", ">")
           .gsub("&#39;", "'").gsub("&quot;", '"').gsub("&nbsp;", " ")
    end

    def norm(value)
      I18n.transliterate(value.to_s).upcase.gsub(/\s+/, " ").strip
    end

    def squish(value)
      value.to_s.gsub(/\s+/, " ").strip
    end
  end
end
