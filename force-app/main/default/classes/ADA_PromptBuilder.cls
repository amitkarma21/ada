public with sharing class ADA_PromptBuilder {
  public static final String RESOURCE_NAME = 'ADA_Explain_Prompt';
  public static final Integer MAX_TOKENS = 700;
  private static final String FALLBACK_PROMPT =
    'You are ADA, a Salesforce admin assistant. Explain in plain language why the user was blocked, using only the facts given. ' +
    'Reply with one JSON object with exactly the keys explanation, fixSteps and suggestedAction (NONE, RAISE_BUG or REQUEST_ACCESS). Never include links.';
  private static String cachedPrompt;

  public static String systemPrompt() {
    if (cachedPrompt == null) {
      cachedPrompt = loadResource();
    }
    return cachedPrompt;
  }

  public static String requestBody(
    String model,
    ADA_PayloadBuilder.LlmBody body
  ) {
    Map<String, Object> request = new Map<String, Object>{
      'model' => model,
      'messages' => new List<Object>{
        message('system', systemPrompt()),
        message('user', ADA_PayloadBuilder.toJson(body))
      },
      'temperature' => 0,
      'max_tokens' => MAX_TOKENS,
      'response_format' => new Map<String, Object>{ 'type' => 'json_object' }
    };
    return JSON.serialize(request);
  }

  private static Map<String, Object> message(String role, String content) {
    return new Map<String, Object>{ 'role' => role, 'content' => content };
  }

  private static String loadResource() {
    List<StaticResource> found = [
      SELECT Body
      FROM StaticResource
      WHERE Name = :RESOURCE_NAME
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (found.isEmpty() || found[0].Body == null) {
      return FALLBACK_PROMPT;
    }
    String text = found[0].Body.toString();
    return String.isBlank(text) ? FALLBACK_PROMPT : text.trim();
  }
}
