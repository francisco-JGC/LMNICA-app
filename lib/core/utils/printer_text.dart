/// Devuelve una copia del string apta para imprimir en la impresora
/// térmica ESC/POS.
///
/// El `Generator` de `esc_pos_utils_plus` llama a `codec.encode(text)` con
/// el codepage activo (CP437/CP850/CP858 típicamente). Si el string
/// contiene un codepoint que el codepage no tiene, tira
/// `ArgumentError: Contains invalid characters` y la impresión falla
/// entera — el ticket queda registrado en el server pero no sale del
/// papel.
///
/// El caso típico es un vendedor con emoji en el nombre ("REYES 👑👑"),
/// un cliente escrito con caracteres decorativos, o un footer con un
/// símbolo Unicode raro. Antes de pasar el string al generador
/// filtramos todo codepoint > 0xFF, que es el techo del Latin-1
/// Supplement (últimos glyphs que los codepages ESC/POS estándar
/// soportan). Tildes, ñ, ¿, ¡, °, ª quedan intactos porque están
/// dentro de ese rango.
///
/// Devuelve `''` si el input es `null` o queda vacío después del
/// filtrado, para que el caller no tenga que null-checkear.
String sanitizeForPrinter(String? input) {
  if (input == null || input.isEmpty) return '';
  final buf = StringBuffer();
  for (final rune in input.runes) {
    // Rango imprimible: ASCII (0x20-0x7E) + control tab/nl si viniera +
    // Latin-1 Supplement (0xA0-0xFF). Excluye control chars <0x20 salvo
    // tab/newline, y emojis / CJK / símbolos altos.
    if (rune == 0x09 || rune == 0x0A) {
      buf.writeCharCode(rune);
    } else if (rune >= 0x20 && rune <= 0xFF) {
      buf.writeCharCode(rune);
    }
    // Los codepoints fuera de rango se descartan silenciosamente.
  }
  // Trim de espacios finales que puedan quedar cuando el emoji era el
  // último char ("REYES 👑" → "REYES ").
  return buf.toString().trimRight();
}
