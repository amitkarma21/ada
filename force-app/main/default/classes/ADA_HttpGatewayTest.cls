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

  private class CountingMock implements HttpCalloutMock {
    public Integer calls = 0;

    public HttpResponse respond(HttpRequest request) {
      calls++;
      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('{}');
      return response;
    }
  }

  private static HttpRequest post(String body) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:ADA_Self_Tooling/anything');
    request.setMethod('POST');
    if (body != null) {
      request.setBody(body);
    }
    return request;
  }

  @IsTest
  static void blocksABodyThatHoldsPersonalData() {
    CountingMock mock = new CountingMock();
    Test.setMock(HttpCalloutMock.class, mock);
    for (
      String body : new List<String>{
        '{"q":"mail jane@example.com.au"}',
        '{"q":"call 0412 345 678"}',
        '{"q":"card 4111 1111 1111 1111"}',
        '{"q":"tfn 123 456 782"}'
      }
    ) {
      try {
        ADA_HttpGateway.execute(post(body));
        Assert.fail('Should have been blocked: ' + body);
      } catch (ADA_BlockedRequestException e) {
        Assert.isFalse(e.kinds.isEmpty());
        Assert.isTrue(e.getMessage().contains('blocked'));
      }
    }
    Assert.areEqual(0, mock.calls);
  }

  @IsTest
  static void sendsACleanBodyAndABodylessRequest() {
    CountingMock mock = new CountingMock();
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    ADA_HttpGateway.execute(
      post('{"errorType":"VALIDATION_RULE","confidence":0.98}')
    );
    ADA_HttpGateway.execute(post(null));
    Test.stopTest();
    Assert.areEqual(2, mock.calls);
  }
}
