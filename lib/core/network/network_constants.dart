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

/// Backoff entre reintentos cuando el refresh falla por algo transitorio
/// (red, timeout, 5xx). Un rechazo explícito del backend no se reintenta.
/// El largo de la lista define la cantidad de reintentos.
const kAuthRefreshRetryDelays = <Duration>[
  Duration(milliseconds: 800),
  Duration(milliseconds: 2400),
];
