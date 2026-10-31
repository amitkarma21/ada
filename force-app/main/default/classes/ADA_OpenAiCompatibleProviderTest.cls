@IsTest
private class ADA_OpenAiCompatibleProviderTest {
  private static ADA_OpenAiCompatibleProvider provider() {
    return new ADA_OpenAiCompatibleProvider('test-model', 4000);
  }

  private static void assertFails(ADA_LlmTestSupport.Mock mock, String part) {
    Test.startTest();
    try {
      provider()
        .explain(ADA_LlmTestSupport.diagnosis(), ADA_LlmTestSupport.extras());
      Assert.fail('Should have failed');
    } catch (ADA_LlmException e) {
      Assert.isTrue(e.getMessage().contains(part), e.getMessage());
    }
    Test.stopTest();
    Assert.areEqual(1, mock.calls);
  }

  @IsTest
  static void aValidAnswerIsReturnedAndTheRequestIsShapedCorrectly() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    ADA_OpenAiCompatibleProvider subject = provider();
    Test.startTest();
    ADA_Explanation answer = subject.explain(
      ADA_LlmTestSupport.diagnosis(),
      ADA_LlmTestSupport.extras()
    );
    Test.stopTest();
    Assert.areEqual('LLM', answer.source);
    Assert.areEqual(2, answer.fixSteps.size());
    HttpRequest sent = mock.requests[0];
    Assert.areEqual('POST', sent.getMethod());
    Assert.areEqual(ADA_OpenAiCompatibleProvider.ENDPOINT, sent.getEndpoint());
    Assert.isTrue(sent.getEndpoint().startsWith('callout:'));
    Assert.areEqual('application/json', sent.getHeader('Content-Type'));
    Assert.areEqual(sent.getBody(), subject.lastPayload());
    Assert.isTrue(sent.getBody().contains('"model":"test-model"'));
  }

  @IsTest
  static void rateLimitingIsReported() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.status = 429;
    mock.body = '{"error":"slow down"}';
    assertFails(mock, '429');
  }

  @IsTest
  static void serverErrorsAreReported() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.status = 500;
    assertFails(mock, '500');
  }

  @IsTest
  static void aBadAnswerIsRejected() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.body = ADA_LlmTestSupport.envelope('{"explanation":"x"}');
    assertFails(mock, 'rejected');
  }

  @IsTest
  static void aTimeoutSurfacesAsACalloutException() {
    ADA_LlmTestSupport.Mock mock = ADA_LlmTestSupport.install();
    mock.timeout = true;
    Test.startTest();
    try {
      provider()
        .explain(ADA_LlmTestSupport.diagnosis(), ADA_LlmTestSupport.extras());
      Assert.fail('Should have timed out');
    } catch (CalloutException e) {
      Assert.isTrue(e.getMessage().contains('timed out'));
    }
    Test.stopTest();
  }

  @IsTest
  static void theLastPayloadIsEmptyBeforeAnyCall() {
    Assert.isNull(provider().lastPayload());
  }
}
