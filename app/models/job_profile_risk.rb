class JobProfileRisk < ApplicationRecord
  belongs_to :job_profile, inverse_of: :risks

  CATEGORIES = {
    1 => "physical",      # Factores de riesgo físico
    2 => "chemical",      # Factores de riesgo químico
    3 => "psycholabor",   # Condiciones psicolaborales
    4 => "biomechanical", # Condiciones biomecánicas
    5 => "safety"         # Condiciones de seguridad
  }.freeze

  EXPOSURE_LEVELS = {
    1 => "1-15%",
    2 => "15-40%",
    3 => "41-60%",
    4 => "61-100%"
  }.freeze

  # Standard INGECOL RH-F-14 risk matrix: ordered [category, factor] pairs.
  # Used to seed new profiles and to map imported "X" marks.
  DEFAULT_FACTORS = [
    [1, "Iluminación"],
    [1, "Energía mecánica (Ruido)"],
    [1, "Energía térmica (frío, calor)"],
    [2, "Contaminación por sustancias tóxicas"],
    [2, "Pegantes, jabones, productos químicos"],
    [3, "Contenido de labores de trabajo"],
    [3, "Organización del tiempo"],
    [3, "Relaciones humanas"],
    [3, "Gestión"],
    [4, "Carga estática (pie, sentado, etc)"],
    [4, "Carga dinámica"],
    [5, "Herramientas"],
    [5, "Maquinaria"],
    [5, "Mecanismos en movimiento"]
  ].freeze

  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :factor, presence: true
  validates :exposure_level, inclusion: { in: EXPOSURE_LEVELS.keys }, allow_nil: true

  def category_key
    CATEGORIES[category]
  end

  def exposure_label
    EXPOSURE_LEVELS[exposure_level]
  end
end
