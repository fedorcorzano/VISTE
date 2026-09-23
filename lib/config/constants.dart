class Constants {
  static const String googleScriptUrl =
      'https://script.google.com/macros/s/AKfycbyeHpQL5egUvdeg4YgCxJsYdCjHKutJvTQr7sagS5zXBoDc64_wemmIYEa8RalW6fC_VQ/exec';
  
  // Nombre de la carpeta designada para almacenamiento de evidencias locales
  static const String localFolderName = 'Vigilarte_Evidencias';

  // Clave de API de Google Gemini (Google AI Studio) para el Asistente Auditor SSOMA
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
}
