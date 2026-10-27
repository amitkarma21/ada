@IsTest
private class ADA_HttpGatewayTest {
  private class OkMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('{"ok":true}');
      return response;
    }
  }

  @IsTest
  static void sendsNamedCredentialRequests() {
    Test.setMock(HttpCalloutMock.class, new OkMock());
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:ADA_Self_Tooling/services/data');
    request.setMethod('GET');
    Test.startTest();
    HttpResponse response = ADA_HttpGateway.execute(request);
    Test.stopTest();
    Assert.areEqual(200, response.getStatusCode());
  }

  @IsTest
  static void rejectsEndpointsThatAreNotNamedCredentials() {
    for (
      String endpoint : new List<String>{
        '/services/data',
        'example.invalid/path',
        '//other-host/path',
        'CALLOUT-not:ADA_X',
        ''
      }
    ) {
      HttpRequest request = new HttpRequest();
      request.setEndpoint(endpoint);
      request.setMethod('GET');
      try {
        ADA_HttpGateway.execute(request);
        Assert.fail('Endpoint should have been rejected: ' + endpoint);
      } catch (ADA_GatewayException e) {
        Assert.isTrue(e.getMessage().contains('Named Credential'));
      }
    }
  }

  @IsTest
  static void rejectsNullRequest() {
    try {
      ADA_HttpGateway.execute(null);
      Assert.fail('Null request should have been rejected');
    } catch (ADA_GatewayException e) {
      Assert.isTrue(e.getMessage().contains('No request'));
    }
  }
}
