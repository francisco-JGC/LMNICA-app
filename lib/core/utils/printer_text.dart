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
const _accentMap = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
  'ñ': 'n', 'Ñ': 'N',
};

String sanitizeForPrinter(String? input) {
  if (input == null || input.isEmpty) return '';
  // Reemplaza tildes y ñ antes del filtro de rango, ya que muchas
  // impresoras térmicas (codepage CP437) no los tienen en su tabla de
  // caracteres y los imprimen como símbolos basura.
  final normalized = input.splitMapJoin(
    RegExp('[áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛñÑ]'),
    onMatch: (m) => _accentMap[m.group(0)!] ?? m.group(0)!,
    onNonMatch: (s) => s,
  );
  final buf = StringBuffer();
  for (final rune in normalized.runes) {
    if (rune == 0x09 || rune == 0x0A) {
      buf.writeCharCode(rune);
    } else if (rune >= 0x20 && rune <= 0xFF) {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString().trimRight();
}
