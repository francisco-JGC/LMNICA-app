// Presupuesto de tiempo de una impresión Bluetooth.
//
// Están todos juntos porque el timeout del controller tiene que ser mayor
// que la suma de los del datasource. Cuando no lo es, el controller se
// rinde mientras la impresión sigue viva: el vendedor ve "tiempo agotado"
// sobre un ticket que en realidad se está imprimiendo, y vuelve a darle a
// Imprimir.
//
// Los valores base son enteros en milisegundos porque `Duration` no se
// puede sumar en una expresión constante.

const _kDisconnectMs = 3000;
const _kPreConnectMs = 300;
const _kConnectMs = 10000;
const _kWriteMs = 15000;
const _kPostWriteMinMs = 1500;
const _kPostWriteMaxMs = 12000;

/// Margen sobre el peor caso, para que el timeout del controller sea la
/// última red de seguridad y no la causa del fallo.
const _kMarginMs = 5000;

/// `PrintBluetoothThermal.disconnect` colgado no debe bloquear el ciclo.
const kPrinterDisconnectTimeout = Duration(milliseconds: _kDisconnectMs);

/// Pausa entre el disconnect preventivo y el connect: el plugin necesita
/// soltar el handle anterior antes de aceptar uno nuevo.
const kPrinterPreConnectDelay = Duration(milliseconds: _kPreConnectMs);

/// `connect()` a una impresora apagada o fuera de rango puede quedar
/// colgado indefinidamente en algunos Android.
const kPrinterConnectTimeout = Duration(milliseconds: _kConnectMs);

/// Envío de los bytes al buffer Bluetooth.
const kPrinterWriteTimeout = Duration(milliseconds: _kWriteMs);

/// `writeBytes` retorna cuando los bytes llegan al buffer BT, no cuando la
/// impresora termina de procesarlos. Si desconectamos de inmediato, la
/// impresora descarta lo que todavía no imprimió. Esperamos proporcional
/// al tamaño: ~40 bytes/ms es conservador para 58mm a 80 mm/s. Un ticket
/// normal (1-3 KB) cae en el mínimo; el máximo solo protege tickets
/// anormalmente grandes.
const kPrinterPostWriteBytesPerMs = 40;
const kPrinterPostWriteMinMs = _kPostWriteMinMs;
const kPrinterPostWriteMaxMs = _kPostWriteMaxMs;

/// Techo de una impresión completa, visto desde el controller. Derivado de
/// las piezas de arriba en vez de ser un número suelto, así subir cualquier
/// timeout del datasource no deja al controller rindiéndose antes de
/// tiempo.
///
/// connect (disconnect + pausa + connect) → write (write + espera) →
/// disconnect final.
const kPrintOperationTimeout = Duration(
  milliseconds: _kDisconnectMs +
      _kPreConnectMs +
      _kConnectMs +
      _kWriteMs +
      _kPostWriteMaxMs +
      _kDisconnectMs +
      _kMarginMs,
);
