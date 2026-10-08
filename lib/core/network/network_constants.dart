// Parámetros de red compartidos por el cliente Dio y el interceptor de
// autenticación.
//
// Viven juntos porque se eligen en conjunto: el refresh y el reintento
// usan Dio limpios (sin interceptores) y antes repetían estos valores a
// mano, con el riesgo de que uno quedara desactualizado respecto al
// cliente principal.

/// Timeouts pensados para operar con datos móviles flakeados y hosting con
/// cold-start: Railway/Render suspenden la instancia por inactividad y
/// despertarla puede tomar 15-25s en la primera request de la mañana. Con
/// los 15-20s de antes eso se le mostraba al vendedor como un timeout,
/// aunque la operación fuera legítima.
const kNetworkConnectTimeout = Duration(seconds: 30);
const kNetworkReceiveTimeout = Duration(seconds: 30);
const kNetworkSendTimeout = Duration(seconds: 30);

/// Ruta de renovación de tokens.
const kAuthRefreshPath = '/auth/refresh';

/// Marca en `RequestOptions.extra` para no reintentar dos veces el mismo
/// request tras un 401.
const kAuthRetriedKey = '_authRetried';

/// Timeout del POST /auth/refresh. Más corto que el de los requests
/// normales a propósito: el refresh es un request diminuto, y encima corre
/// DETRÁS del spinner de una acción del usuario (vender e imprimir). Si no
/// contesta en este plazo, reintentar es mejor que seguir esperando.
const kAuthRefreshTimeout = Duration(seconds: 12);

/// Backoff entre reintentos cuando el refresh falla por algo transitorio
/// (red, timeout, 5xx). Un rechazo explícito del backend no se reintenta.
/// El largo de la lista define la cantidad de reintentos.
///
/// Un solo reintento a propósito: no perder la sesión ya está garantizado
/// por tratar el fallo transitorio como "no se pudo preguntar" en vez de
/// "sesión muerta". Los reintentos solo salvan el request en curso, y cada
/// uno se paga en segundos de botón girando.
///
/// Peor caso total: 12s + 800ms + 12s ≈ 25s.
const kAuthRefreshRetryDelays = <Duration>[
  Duration(milliseconds: 800),
];

/// Tope de las validaciones best-effort previas a registrar una venta
/// (mínimo por número, máximo por boleto). Corren con el botón Imprimir ya
/// girando y el backend las vuelve a aplicar igual, así que es preferible
/// seguir adelante antes que hacer esperar al vendedor.
const kPreSaleCheckTimeout = Duration(seconds: 6);
