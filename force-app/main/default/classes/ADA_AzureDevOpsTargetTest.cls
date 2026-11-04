@IsTest
private class ADA_AzureDevOpsTargetTest {
  private static ADA_AzureDevOpsTarget target() {
    return new ADA_AzureDevOpsTarget(ADA_AdoTestSupport.setting());
  }

  private static List<Object> patchOf(HttpRequest request) {
    return (List<Object>) JSON.deserializeUntyped(request.getBody());
  }

  private static Map<String, Object> fieldsOf(HttpRequest request) {
    Map<String, Object> fields = new Map<String, Object>();
    for (Object item : patchOf(request)) {
      Map<String, Object> op = (Map<String, Object>) item;
      fields.put(
        ((String) op.get('path')).substringAfter('/fields/'),
        op.get('value')
      );
    }
    return fields;
  }

  @IsTest
  static void aMissSearchesThenCreatesOneBug() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(200, ADA_AdoTestSupport.created(42, ADA_AdoTestSupport.HTML_LINK));
    ADA_ActionResult result = target()
      .submit('key-1', ADA_AdoTestSupport.payload(null));
    Assert.isTrue(result.success, result.message);
    Assert.areEqual('Success', result.status);
    Assert.areEqual('AzureDevOps', result.target);
    Assert.areEqual('42', result.externalId);
    Assert.areEqual(ADA_AdoTestSupport.HTML_LINK, result.externalUrl);
    Assert.areEqual(2, mock.requests.size());
    HttpRequest search = mock.requests[0];
    Assert.areEqual('POST', search.getMethod());
    Assert.isTrue(
      search.getEndpoint()
        .startsWith('callout:ADA_AzureDevOps/My%20Project/_apis/wit/wiql'),
      search.getEndpoint()
    );
    Assert.isTrue(
      search.getBody().contains('ADA-rule:' + ADA_AdoTestSupport.RULE),
      search.getBody()
    );
    HttpRequest create = mock.requests[1];
    Assert.areEqual('POST', create.getMethod());
    Assert.isTrue(
      create.getEndpoint()
        .startsWith(
          'callout:ADA_AzureDevOps/My%20Project/_apis/wit/workitems/%24Bug'
        ),
      create.getEndpoint()
    );
    Assert.areEqual(
      'application/json-patch+json',
      create.getHeader('Content-Type')
    );
  }

  @IsTest
  static void aHitLinksTheExistingBugAndCreatesNothing() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.hit(77));
    ADA_ActionResult result = target()
      .submit('key-2', ADA_AdoTestSupport.payload(null));
    Assert.isTrue(result.success, result.message);
    Assert.areEqual('77', result.externalId);
    Assert.areEqual(
      'https://dev.azure.com/acme/0b1c2d3e/_workitems/edit/77', // ada-allow-url
      result.externalUrl
    );
    Assert.isTrue(result.message.contains('already'), result.message);
    Assert.areEqual(1, mock.requests.size());
  }

  @IsTest
  static void theCreateBodyHoldsExactlyTheFieldsInTheContract() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(200, ADA_AdoTestSupport.created(42, ADA_AdoTestSupport.HTML_LINK));
    target().submit('key-3', ADA_AdoTestSupport.payload('Happens every time.'));
    Map<String, Object> fields = fieldsOf(mock.requests[1]);
    Assert.areEqual(
      new Set<String>{
        'System.Title',
        'System.Description',
        'System.Tags',
        'System.AreaPath'
      },
      fields.keySet()
    );
    for (Object item : patchOf(mock.requests[1])) {
      Assert.areEqual('add', ((Map<String, Object>) item).get('op'));
    }
    Assert.areEqual(
      'ADA; ADA-rule:' + ADA_AdoTestSupport.RULE,
      fields.get('System.Tags')
    );
    Assert.areEqual('My Project\\ADA', fields.get('System.AreaPath'));
    Assert.isTrue(((String) fields.get('System.Title')).startsWith('ADA: '));
    String description = (String) fields.get('System.Description');
    Assert.isTrue(description.contains('Session: abc123'), description);
    Assert.isTrue(description.contains('Happens every time.'), description);
    Assert.isTrue(description.contains('<br>'), description);
  }

  @IsTest
  static void noAreaPathMeansNoAreaPathField() {
    ADA_Setting__mdt setting = ADA_AdoTestSupport.setting();
    setting.ADO_Area_Path__c = null;
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(200, ADA_AdoTestSupport.created(42, ADA_AdoTestSupport.HTML_LINK));
    new ADA_AzureDevOpsTarget(setting)
      .submit('key-4', ADA_AdoTestSupport.payload(null));
    Assert.isFalse(fieldsOf(mock.requests[1]).containsKey('System.AreaPath'));
  }

  @IsTest
  static void userNotesWithMarkupAreEscaped() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(200, ADA_AdoTestSupport.created(42, ADA_AdoTestSupport.HTML_LINK));
    target()
      .submit(
        'key-5',
        ADA_AdoTestSupport.payload(
          '<script>alert(1)</script> & <img src=x onerror=alert(2)>'
        )
      );
    String description = (String) fieldsOf(mock.requests[1])
      .get('System.Description');
    Assert.isFalse(description.contains('<script'), description);
    Assert.isFalse(description.contains('<img'), description);
    Assert.isTrue(description.contains('&lt;script&gt;'), description);
    Assert.isTrue(description.contains('&amp;'), description);
  }

  @IsTest
  static void aLongTitleIsClippedToTheAzureLimit() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(200, ADA_AdoTestSupport.created(42, ADA_AdoTestSupport.HTML_LINK));
    ADA_PayloadBuilder.WorkItemBody body = ADA_PayloadBuilder.forWorkItem(
      ADA_AdoTestSupport.diagnosis(),
      'abc123',
      null
    );
    body.title = 'T'.repeat(400);
    target().submit('key-6', ADA_PayloadBuilder.toJson(body));
    Assert.areEqual(
      255,
      ((String) fieldsOf(mock.requests[1]).get('System.Title')).length()
    );
  }

  @IsTest
  static void aPayloadWithoutARuleTagSkipsTheSearch() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.created(42, ADA_AdoTestSupport.HTML_LINK));
    ADA_PayloadBuilder.WorkItemBody body = ADA_PayloadBuilder.forWorkItem(
      ADA_AdoTestSupport.diagnosis(),
      'abc123',
      null
    );
    body.tags = 'ADA';
    ADA_ActionResult result = target()
      .submit('key-7', ADA_PayloadBuilder.toJson(body));
    Assert.isTrue(result.success, result.message);
    Assert.areEqual(1, mock.requests.size());
  }

  @IsTest
  static void aRuleNameThatIsNotAnApiNameIsRefusedBeforeAnyCallout() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install();
    ADA_PayloadBuilder.WorkItemBody body = ADA_PayloadBuilder.forWorkItem(
      ADA_AdoTestSupport.diagnosis(),
      'abc123',
      null
    );
    body.tags = 'ADA; ADA-rule:X\' OR [System.Id] > 0 OR \'a\' = \'a';
    ADA_ActionResult result = target()
      .submit('key-8', ADA_PayloadBuilder.toJson(body));
    Assert.isFalse(result.success);
    Assert.areEqual('Failed', result.status);
    Assert.areEqual(0, mock.requests.size());
  }

  private static ADA_ActionResult failOnSearch(Integer status, String body) {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(status, body);
    ADA_ActionResult result = target()
      .submit('key-e', ADA_AdoTestSupport.payload(null));
    Assert.isFalse(result.success, String.valueOf(status));
    Assert.areEqual('Failed', result.status);
    Assert.areEqual(1, mock.requests.size(), 'no create after a failed search');
    return result;
  }

  @IsTest
  static void eachSearchErrorGetsAPlainMessage() {
    Assert.isTrue(failOnSearch(401, '{}').message.contains('401'));
    Assert.isTrue(failOnSearch(403, '{}').message.contains('403'));
    Assert.isTrue(failOnSearch(404, '{}').message.contains('project'));
    Assert.isTrue(failOnSearch(429, '{}').message.contains('rate limiting'));
    Assert.isTrue(failOnSearch(500, '{}').message.contains('500'));
  }

  @IsTest
  static void aSignInPageWithStatus203MeansABadToken() {
    ADA_ActionResult result = failOnSearch(203, '<html>Sign In</html>');
    Assert.isTrue(result.message.contains('401'), result.message);
  }

  @IsTest
  static void eachCreateErrorGetsAPlainMessage() {
    for (Integer status : new List<Integer>{ 400, 401, 403, 404, 429, 500 }) {
      ADA_AdoTestSupport.install()
        .then(200, ADA_AdoTestSupport.noHit())
        .then(status, '{"message":"secret detail from the server"}');
      ADA_ActionResult result = target()
        .submit('key-c' + status, ADA_AdoTestSupport.payload(null));
      Assert.isFalse(result.success, String.valueOf(status));
      Assert.isTrue(
        result.message.contains(String.valueOf(status)) ||
          result.message.contains('project') ||
          result.message.contains('rate limiting'),
        status + ': ' + result.message
      );
      Assert.isFalse(result.message.contains('secret detail'), result.message);
      Assert.isNull(result.externalId);
    }
  }

  @IsTest
  static void aTimeoutOrABrokenReplyIsAFailureNotAnException() {
    ADA_AdoTestSupport.Mock slow = ADA_AdoTestSupport.install();
    slow.timeout = true;
    Assert.isFalse(
      target().submit('key-t', ADA_AdoTestSupport.payload(null)).success
    );
    ADA_AdoTestSupport.install().then(200, 'not json');
    Assert.isFalse(
      target().submit('key-j', ADA_AdoTestSupport.payload(null)).success
    );
    ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(200, '{"id":"abc"}');
    Assert.isFalse(
      target().submit('key-i', ADA_AdoTestSupport.payload(null)).success
    );
  }

  @IsTest
  static void aLinkThatIsNotHttpsIsNeverReturned() {
    ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit())
      .then(
        200,
        '{"id":42,"url":"http://host/_apis/wit/workItems/42","_links":{"html":{"href":"javascript:alert(1)"}}}' // ada-allow-url
      );
    ADA_ActionResult result = target()
      .submit('key-l', ADA_AdoTestSupport.payload(null));
    Assert.isTrue(result.success, result.message);
    Assert.areEqual('42', result.externalId);
    Assert.isNull(result.externalUrl);
  }

  @IsTest
  static void notSetUpOrBadInputMakesNoCallout() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install();
    ADA_Setting__mdt off = ADA_AdoTestSupport.setting();
    off.ADO_Enabled__c = false;
    Assert.isFalse(
      new ADA_AzureDevOpsTarget(off)
        .submit('key-o', ADA_AdoTestSupport.payload(null))
        .success
    );
    ADA_Setting__mdt noProject = ADA_AdoTestSupport.setting();
    noProject.ADO_Project__c = ' ';
    Assert.isFalse(
      new ADA_AzureDevOpsTarget(noProject)
        .submit('key-p', ADA_AdoTestSupport.payload(null))
        .success
    );
    Assert.isFalse(
      new ADA_AzureDevOpsTarget(null)
        .submit('key-n', ADA_AdoTestSupport.payload(null))
        .success
    );
    Assert.isFalse(
      target().submit(' ', ADA_AdoTestSupport.payload(null)).success
    );
    Assert.isFalse(target().submit('key-b', null).success);
    Assert.isFalse(target().submit('key-b', 'not json').success);
    Assert.isFalse(target().submit('key-b', '{"title":" "}').success);
    Assert.areEqual(0, mock.requests.size());
  }

  @IsTest
  static void aBodyWithPersonalDataIsBlockedAtTheGateway() {
    ADA_AdoTestSupport.Mock mock = ADA_AdoTestSupport.install()
      .then(200, ADA_AdoTestSupport.noHit());
    ADA_PayloadBuilder.WorkItemBody body = ADA_PayloadBuilder.forWorkItem(
      ADA_AdoTestSupport.diagnosis(),
      'abc123',
      null
    );
    body.description = 'Contact jo.citizen@example.org about it';
    ADA_ActionResult result = target()
      .submit('key-x', ADA_PayloadBuilder.toJson(body));
    Assert.areEqual('Blocked', result.status);
    Assert.isFalse(result.success);
    Assert.areEqual(1, mock.requests.size(), 'only the clean search went out');
  }

  @IsTest
  static void theTargetNameIsAzureDevOps() {
    Assert.areEqual('AzureDevOps', target().targetName());
  }
}
