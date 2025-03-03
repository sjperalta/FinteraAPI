module NumberToWords
  # Converts a number (Integer or Float) into its Spanish words representation.
  # If the number has a non-zero decimal part, it is handled as a measurement.
  #
  # Examples:
  #   NumberToWords.numero_a_letras(410.20)
  #   # => "CUATROCIENTOS DIEZ PUNTO DOS CERO"
  #
  def self.numero_a_letras(numero)
    integer_part, decimal_part = sprintf('%.2f', numero).split('.')
    words = convert_integer_to_words(integer_part.to_i)
    if decimal_part && decimal_part.to_i > 0
      words += " punto " + convert_decimal_to_words(decimal_part)
    end
    words.upcase
  end

  # Converts a number (Integer or Float) into its currency representation in words.
  # For example, 415.00 will output:
  #   "CUATROCIENTOS QUINCE LEMPIRAS EXACTOS"
  #
  # If there is a non-zero cent value (e.g. 415.50), it outputs:
  #   "CUATROCIENTOS QUINCE LEMPIRAS CON 50/100"
  #
  # currency - A String representing the currency unit (default: "LEMPIRAS").
  #
  # Examples:
  #   NumberToWords.currency_a_letras(415.00)
  #   # => "CUATROCIENTOS QUINCE LEMPIRAS EXACTOS"
  #
  #   NumberToWords.currency_a_letras(415.50)
  #   # => "CUATROCIENTOS QUINCE LEMPIRAS CON 50/100"
  #
  def self.currency_a_letras(numero, currency = "LEMPIRAS")
    integer_part, decimal_part = sprintf('%.2f', numero).split('.')
    words = convert_integer_to_words(integer_part.to_i)
    if decimal_part.to_i == 0
      words += " #{currency} EXACTOS"
    else
      words += " #{currency} CON #{decimal_part}/100"
    end
    words.upcase
  end

  private

  # Converts the integer part of a number into words.
  def self.convert_integer_to_words(n)
    return "cero" if n == 0
    return "menos " + convert_integer_to_words(-n) if n < 0

    words = ""

    if n >= 1_000_000_000
      billions = n / 1_000_000_000
      n %= 1_000_000_000
      words += "#{convert_integer_to_words(billions)} mil millones"
      words += " " if n > 0
    end

    if n >= 1_000_000
      millions = n / 1_000_000
      n %= 1_000_000
      if millions == 1
        words += "un millón"
      else
        words += "#{convert_integer_to_words(millions)} millones"
      end
      words += " " if n > 0
    end

    if n >= 1000
      thousands = n / 1000
      n %= 1000
      if thousands == 1
        words += "mil"
      else
        words += "#{convert_integer_to_words(thousands)} mil"
      end
      words += " " if n > 0
    end

    if n > 0
      words += convert_hundreds(n)
    end

    words
  end

  # Converts numbers less than 1000 into words.
  def self.convert_hundreds(n)
    units = ["", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]
    teens = ["diez", "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve"]
    tens  = ["", "", "veinte", "treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa"]
    hundreds = ["", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos", "seiscientos", "setecientos", "ochocientos", "novecientos"]

    return "cien" if n == 100

    h = n / 100
    t = (n % 100) / 10
    u = n % 10

    result = ""
    result += hundreds[h] + " " if h > 0

    if t == 0 || t == 1
      if t == 1
        result += teens[u]
      else
        result += units[u]
      end
    else
      if t == 2 && u != 0
        mapping = {
          1 => "veintiuno", 2 => "veintidós", 3 => "veintitrés", 4 => "veinticuatro",
          5 => "veinticinco", 6 => "veintiséis", 7 => "veintisiete", 8 => "veintiocho", 9 => "veintinueve"
        }
        result += mapping[u]
      else
        result += tens[t]
        result += " y " + units[u] if u > 0
      end
    end

    result.strip
  end

  # Converts the decimal part by converting each digit individually.
  def self.convert_decimal_to_words(decimal_str)
    digit_words = {
      "0" => "cero",
      "1" => "uno",
      "2" => "dos",
      "3" => "tres",
      "4" => "cuatro",
      "5" => "cinco",
      "6" => "seis",
      "7" => "siete",
      "8" => "ocho",
      "9" => "nueve"
    }
    decimal_str.chars.map { |ch| digit_words[ch] }.join(" ")
  end
end
