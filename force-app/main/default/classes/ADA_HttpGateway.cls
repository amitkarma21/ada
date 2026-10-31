public with sharing class ADA_HttpGateway {
  private static final String NAMED_CREDENTIAL_PREFIX = 'callout:';

  public static HttpResponse execute(HttpRequest request) {
    if (request == null) {
      throw new ADA_GatewayException('No request to send.');
    }
    String endpoint = request.getEndpoint();
    if (
      String.isBlank(endpoint) || !endpoint.startsWith(NAMED_CREDENTIAL_PREFIX)
    ) {
      throw new ADA_GatewayException(
        'Only Named Credential endpoints are allowed.'
      );
    }
    blockPersonalData(request.getBody());
    return new Http().send(request);
  }

  // Last line of defence: whatever built the body, personal data never leaves.
  private static void blockPersonalData(String body) {
    if (String.isBlank(body)) {
      return;
    }
    Set<String> kinds = ADA_PiiGate.detect(body);
    if (kinds.isEmpty()) {
      return;
    }
    ADA_BlockedRequestException blocked = new ADA_BlockedRequestException(
      'The request was blocked because it contains personal data (' +
        String.join(new List<String>(kinds), ', ') +
        ').'
    );
    blocked.kinds = kinds;
    throw blocked;
  }
}
