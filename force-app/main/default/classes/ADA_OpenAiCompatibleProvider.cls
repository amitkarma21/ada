public with sharing class ADA_OpenAiCompatibleProvider implements ADA_ILlmProvider {
  public static final String ENDPOINT = 'callout:ADA_LLM/chat/completions';
  private final String model;
  private final Integer timeoutMs;
  private String sent;

  public ADA_OpenAiCompatibleProvider(String model, Integer timeoutMs) {
    this.model = model;
    this.timeoutMs = timeoutMs;
  }

  public ADA_Explanation explain(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  ) {
    sent = null;
    sent = ADA_PromptBuilder.requestBody(
      model,
      ADA_PayloadBuilder.forLlm(diagnosis, extras)
    );
    HttpRequest request = new HttpRequest();
    request.setEndpoint(ENDPOINT);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Accept', 'application/json');
    request.setTimeout(timeoutMs);
    request.setBody(sent);
    HttpResponse response = ADA_HttpGateway.execute(request);
    Integer status = response.getStatusCode();
    if (status == 429) {
      throw new ADA_LlmException(
        'The model provider is rate limiting requests (429).'
      );
    }
    if (status < 200 || status > 299) {
      throw new ADA_LlmException(
        'The model provider returned status ' + status + '.'
      );
    }
    return ADA_LlmResponseValidator.parse(response.getBody());
  }

  public String lastPayload() {
    return sent;
  }
}
