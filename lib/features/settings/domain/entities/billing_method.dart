enum BillingMethod {
  bluetoothPrinter,
  whatsapp;

  String get displayName => switch (this) {
        BillingMethod.bluetoothPrinter => 'Impresora por Bluetooth',
        BillingMethod.whatsapp => 'Enviar por WhatsApp',
      };

  /// Descripción corta para el subtítulo del radio en la Settings page.
  String get description => switch (this) {
        BillingMethod.bluetoothPrinter =>
          'Imprime el ticket en la impresora térmica.',
        BillingMethod.whatsapp =>
          'Genera una imagen del ticket y la comparte por WhatsApp u otras apps.',
      };

  /// Label del botón principal en la pantalla del juego.
  String get actionLabel => switch (this) {
        BillingMethod.bluetoothPrinter => 'Imprimir',
        BillingMethod.whatsapp => 'Enviar',
      };

  static BillingMethod fromKey(String? key) {
    return BillingMethod.values.firstWhere(
      (m) => m.name == key,
      orElse: () => BillingMethod.bluetoothPrinter,
    );
  }
}
