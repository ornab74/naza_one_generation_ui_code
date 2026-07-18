final class FoodVisionConfig {
  const FoodVisionConfig._();

  static const String appName = 'Naza Kitchen';
  static const String modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String modelPathEnvironmentVariable = 'NAZA_MODEL_PATH';
  static const String modelDownloadUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/7fa1d78473894f7e736a21d920c3aa80f950c0db/gemma-4-E2B-it.litertlm';
  static const String modelSha256 =
      'ab7838cdfc8f77e54d8ca45eadceb20452d9f01e4bfade03e5dce27911b27e42';

  static const int contextTokens = 3072;
  static const int fridgeOutputTokens = 640;
  static const int recipeOutputTokens = 640;
  static const int bakeOutputTokens = 420;
  static const int visionMaxImages = 1;
  static const int visionMaxImageDimension = 1280;
  static const int visionMaxSourceImageBytes = 32 * 1024 * 1024;
  static const int visionMaxImageBytes = 8 * 1024 * 1024;
  static const int runtimeInitTimeoutSeconds = 30;
  static const int modelInstallTimeoutSeconds = 300;
  static const int modelLoadTimeoutSeconds = 90;
  static const int sessionOpenTimeoutSeconds = 15;
  static const int promptSubmitTimeoutSeconds = 12;
  static const int generationIdleTimeoutSeconds = 24;
  static const int generationTotalTimeoutSeconds = 95;
  static const int nativeStopTimeoutSeconds = 2;

  static const int fridgeLogLimit = 180;
  static const int bakeLogLimit = 240;
  static const int recentTrendLogCount = 14;
  static const int maxModelResponseChars = 30000;

  static const String fridgeNamespace = 'food-fridge-v1';
  static const String fridgeIndexKey = 'index';
  static const String bakeNamespace = 'food-bake-v1';
  static const String bakeIndexKey = 'index';
  static const String preferenceNamespace = 'food-settings-v1';
  static const String preferenceKey = 'preferences';
}
