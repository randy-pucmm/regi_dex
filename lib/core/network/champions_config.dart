// Configuración del servicio Pokémon Champions Battle Data (ADR-008).

/// Raíz del servicio. Se cambia con `--dart-define=CHAMPIONS_ENDPOINT=...`.
const defaultChampionsEndpoint = 'https://championsbattledata.com';

/// Espera máxima por el índice (RNF-RES-01); pesa unos 18 MB sin comprimir.
const championsIndexTimeout = Duration(seconds: 20);

/// Espera máxima por las estadísticas de uso de un Pokémon.
const championsBattleTimeout = Duration(seconds: 10);

/// Vigencia de la caché del índice y de las estadísticas de uso (RNF-API-02).
const championsCacheMaxAge = Duration(hours: 24);
