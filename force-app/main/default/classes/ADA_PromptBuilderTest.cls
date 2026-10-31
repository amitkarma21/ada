@IsTest
private class ADA_PromptBuilderTest {
  private static final Set<String> CONTRACT = new Set<String>{
    'errorType',
    'objectApiName',
    'objectLabel',
    'componentType',
    'componentApiName',
    'componentLabel',
    'componentDescription',
    'conditionFormulaMasked',
    'fieldLabels',
    'missingPermissionLabels',
    'userQuestion',
    'locale'
  };

  @IsTest
  static void theSystemPromptIsLoadedAndAsksForJson() {
    String prompt = ADA_PromptBuilder.systemPrompt();
    Assert.isFalse(String.isBlank(prompt));
    Assert.isTrue(prompt.contains('suggestedAction'));
    Assert.isTrue(prompt.contains('fixSteps'));
    Assert.areEqual(prompt, ADA_PromptBuilder.systemPrompt());
  }

  @IsTest
  static void theRequestCarriesOnlyTheContractFields() {
    ADA_PayloadBuilder.Extras extras = ADA_LlmTestSupport.extras();
    extras.userQuestion = 'Why can I not save this deal?';
    extras.missingPermissionLabels = new List<String>{ 'Sales Operations' };
    String json = ADA_PromptBuilder.requestBody(
      'test-model',
      ADA_PayloadBuilder.forLlm(ADA_LlmTestSupport.diagnosis(), extras)
    );
    Map<String, Object> request = (Map<String, Object>) System.JSON.deserializeUntyped(
      json
    );
    Assert.areEqual(
      new Set<String>{
        'model',
        'messages',
        'temperature',
        'max_tokens',
        'response_format'
      },
      request.keySet()
    );
    Assert.areEqual('test-model', request.get('model'));
    Assert.areEqual(0, request.get('temperature'));
    Assert.areEqual(ADA_PromptBuilder.MAX_TOKENS, request.get('max_tokens'));
    List<Object> messages = (List<Object>) request.get('messages');
    Assert.areEqual(2, messages.size());
    Map<String, Object> systemMessage = (Map<String, Object>) messages[0];
    Map<String, Object> user = (Map<String, Object>) messages[1];
    Assert.areEqual('system', systemMessage.get('role'));
    Assert.areEqual('user', user.get('role'));
    Map<String, Object> userContent = (Map<String, Object>) System.JSON.deserializeUntyped(
      (String) user.get('content')
    );
    Assert.areEqual(CONTRACT, userContent.keySet());
    Assert.areEqual('Close_Date_Rule', userContent.get('componentApiName'));
  }
}
