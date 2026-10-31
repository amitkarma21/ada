@IsTest
private class ADA_ToolingClientTest {
  private static final String BASE = 'callout:ADA_Self_Tooling';
  private static final String SOQL = 'SELECT Id, ValidationName FROM ValidationRule';

  private class QueueMock implements HttpCalloutMock {
    public List<HttpResponse> queue = new List<HttpResponse>();
    public List<HttpRequest> seen = new List<HttpRequest>();
    public Boolean endless = false;
    public Boolean throwCalloutException = false;

    public HttpResponse respond(HttpRequest request) {
      seen.add(request);
      if (throwCalloutException) {
        throw new CalloutException('Named credential not found');
      }
      if (endless) {
        return page(
          '{"done":false,"nextRecordsUrl":"/services/data/v68.0/tooling/query/01g-' +
            seen.size() +
            '","records":[{"Id":"1"}]}'
        );
      }
      return queue.remove(0);
    }
  }

  private static HttpResponse reply(Integer status, String body) {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(status);
    response.setBody(body);
    return response;
  }

  private static HttpResponse page(String body) {
    return reply(200, body);
  }

  private static QueueMock mockWith(List<HttpResponse> responses) {
    QueueMock mock = new QueueMock();
    mock.queue = responses;
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  private static String errorOf(String soql) {
    try {
      new ADA_ToolingClient().query(soql);
    } catch (ADA_ToolingClient.ToolingException e) {
      return e.getMessage();
    }
    return null;
  }

  @IsTest
  static void sendsEncodedQueryToTheNamedCredential() {
    QueueMock mock = mockWith(
      new List<HttpResponse>{
        page(
          '{"done":true,"records":[{"Id":"03d1","ValidationName":"Rule_A"}]}'
        )
      }
    );
    Test.startTest();
    List<Map<String, Object>> records = new ADA_ToolingClient().query(SOQL);
    Test.stopTest();
    Assert.areEqual(1, records.size());
    Assert.areEqual('Rule_A', records[0].get('ValidationName'));
    Assert.areEqual(1, mock.seen.size());
    Assert.areEqual('GET', mock.seen[0].getMethod());
    Assert.areEqual(
      BASE +
        '/services/data/v68.0/tooling/query/?q=' +
        EncodingUtil.urlEncode(SOQL, 'UTF-8'),
      mock.seen[0].getEndpoint()
    );
  }

  @IsTest
  static void queryDataUsesTheDataApiQueryPathAndFollowsPages() {
    QueueMock mock = mockWith(
      new List<HttpResponse>{
        page(
          '{"done":false,"nextRecordsUrl":"/services/data/v68.0/query/01g-2000","records":[{"Id":"1"}]}'
        ),
        page('{"done":true,"records":[{"Id":"2"}]}')
      }
    );
    String soql = 'SELECT Id FROM DuplicateRule';
    Test.startTest();
    List<Map<String, Object>> records = new ADA_ToolingClient().queryData(soql);
    Test.stopTest();
    Assert.areEqual(2, records.size());
    Assert.areEqual(
      BASE +
        '/services/data/v68.0/query/?q=' +
        EncodingUtil.urlEncode(soql, 'UTF-8'),
      mock.seen[0].getEndpoint()
    );
    Assert.areEqual(
      BASE + '/services/data/v68.0/query/01g-2000',
      mock.seen[1].getEndpoint()
    );
  }

  @IsTest
  static void queryDataRequiresAQuery() {
    try {
      new ADA_ToolingClient().queryData(' ');
      Assert.fail('Expected a ToolingException');
    } catch (ADA_ToolingClient.ToolingException e) {
      Assert.isTrue(e.getMessage().contains('required'));
    }
  }

  @IsTest
  static void emptyResultIsAnEmptyList() {
    mockWith(new List<HttpResponse>{ page('{"done":true,"records":[]}') });
    Test.startTest();
    List<Map<String, Object>> records = new ADA_ToolingClient().query(SOQL);
    Test.stopTest();
    Assert.isTrue(records.isEmpty());
  }

  @IsTest
  static void followsNextRecordsUrlUntilDone() {
    QueueMock mock = mockWith(
      new List<HttpResponse>{
        page(
          '{"done":false,"nextRecordsUrl":"/services/data/v68.0/tooling/query/01g-2000","records":[{"Id":"1"}]}'
        ),
        page('{"done":true,"records":[{"Id":"2"},{"Id":"3"}]}')
      }
    );
    Test.startTest();
    List<Map<String, Object>> records = new ADA_ToolingClient().query(SOQL);
    Test.stopTest();
    Assert.areEqual(3, records.size());
    Assert.areEqual(2, mock.seen.size());
    Assert.areEqual(
      BASE + '/services/data/v68.0/tooling/query/01g-2000',
      mock.seen[1].getEndpoint()
    );
  }

  @IsTest
  static void rejectsNextRecordsUrlOutsideTheDataApi() {
    mockWith(
      new List<HttpResponse>{
        page(
          '{"done":false,"nextRecordsUrl":"//other-host/steal","records":[]}'
        )
      }
    );
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('unexpected'));
  }

  @IsTest
  static void stopsAfterThePageCap() {
    QueueMock mock = new QueueMock();
    mock.endless = true;
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('too many pages'));
    Assert.areEqual(ADA_ToolingClient.MAX_PAGES, mock.seen.size());
  }

  @IsTest
  static void unauthorisedTellsTheAdminToReconnect() {
    mockWith(
      new List<HttpResponse>{
        reply(
          401,
          '[{"message":"Session expired","errorCode":"INVALID_SESSION_ID"}]'
        )
      }
    );
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('Run the ADA setup to reconnect'));
  }

  @IsTest
  static void badRequestSurfacesTheApiError() {
    mockWith(
      new List<HttpResponse>{
        reply(
          400,
          '[{"message":"unexpected token","errorCode":"MALFORMED_QUERY"}]'
        )
      }
    );
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('MALFORMED_QUERY'));
    Assert.isTrue(message.contains('unexpected token'));
  }

  @IsTest
  static void badRequestWithUnreadableBodyStillHasAStatus() {
    mockWith(new List<HttpResponse>{ reply(400, 'not json') });
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('400'));
  }

  @IsTest
  static void serverErrorMentionsTheStatus() {
    mockWith(new List<HttpResponse>{ reply(500, 'boom') });
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('500'));
    Assert.isFalse(message.contains('boom'));
  }

  @IsTest
  static void malformedJsonIsReportedClearly() {
    mockWith(new List<HttpResponse>{ page('<html>not json</html>') });
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('unreadable'));
  }

  @IsTest
  static void jsonWithoutRecordsIsReportedClearly() {
    mockWith(new List<HttpResponse>{ page('{"done":true}') });
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('unreadable'));
  }

  @IsTest
  static void missingConnectionPointsToSetup() {
    QueueMock mock = new QueueMock();
    mock.throwCalloutException = true;
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    String message = errorOf(SOQL);
    Test.stopTest();
    Assert.isNotNull(message);
    Assert.isTrue(message.contains('Run the ADA setup'));
  }

  @IsTest
  static void blankQueryIsRejectedBeforeAnyCallout() {
    QueueMock mock = mockWith(new List<HttpResponse>());
    String message = errorOf('  ');
    Assert.isNotNull(message);
    Assert.areEqual(0, mock.seen.size());
  }
}
