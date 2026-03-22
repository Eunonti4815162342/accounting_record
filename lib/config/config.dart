class Config {
  // Ahora usamos el nombre de red de Tailscale para producción
  static const String apiUrl = String.fromEnvironment(
    'API_URL', 
    defaultValue: 'https://llama-pi.tu-usuario.ts.net/api' 
  );

  static Map<String, String> getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
