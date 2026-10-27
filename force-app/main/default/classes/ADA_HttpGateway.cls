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
    return new Http().send(request);
  }
}
