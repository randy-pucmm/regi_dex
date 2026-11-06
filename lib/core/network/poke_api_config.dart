/// Endpoint GraphQL de PokéAPI (solo POST).
const defaultPokeApiEndpoint = 'https://graphql.pokeapi.co/v1beta2';

/// Tiempo máximo para abrir la conexión.
const defaultConnectTimeout = Duration(seconds: 5);

/// Tiempo máximo para recibir la respuesta completa.
const defaultResponseTimeout = Duration(seconds: 10);

/// Tiempo máximo del health-check.
const healthCheckTimeout = Duration(seconds: 5);
