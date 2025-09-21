module MeasurementUnits
  M2_TO_FT2 = 10.7639
  M2_TO_VARA2 = 1.431

  def self.convert_area(area_m2, unit)
    case unit
    when nil, 'm2'
      area_m2
    when 'ft2'
      area_m2 * M2_TO_FT2
    when 'vara2'
      area_m2 * M2_TO_VARA2
    else
      area_m2
    end
  end
end
