module ApplicationHelper
  # Usando un ejemplo simple, con un método de conversión a palabras.
  #
  def currency_to_words(amount)
    NumberToWords.currency_a_letras(amount)
  end

  def number_to_words(amount)
    NumberToWords.numero_a_letras(amount)
  end
end
