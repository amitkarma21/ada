@IsTest
private class ADA_LlmProviderFactoryTest {
  @IsTest
  static void templateIsTheDefault() {
    ADA_LlmProviderFactory.settingOverride = new ADA_Setting__mdt(
      LLM_Provider__c = 'Template'
    );
    Assert.isInstanceOfType(
      ADA_LlmProviderFactory.create(),
      ADA_TemplateProvider.class
    );
  }

  @IsTest
  static void aModelAndTheCompatibleProviderGiveTheLlmProvider() {
    ADA_LlmTestSupport.useOpenAi();
    Assert.isInstanceOfType(
      ADA_LlmProviderFactory.create(),
      ADA_OpenAiCompatibleProvider.class
    );
  }

  @IsTest
  static void aMissingModelOrAnUnbuiltProviderFallsBackToTemplate() {
    ADA_LlmTestSupport.useProvider('OpenAICompatible', ' ');
    Assert.isInstanceOfType(
      ADA_LlmProviderFactory.create(),
      ADA_TemplateProvider.class
    );
    ADA_LlmTestSupport.useProvider('Anthropic', 'some-model');
    Assert.isInstanceOfType(
      ADA_LlmProviderFactory.create(),
      ADA_TemplateProvider.class
    );
    ADA_LlmTestSupport.useProvider(null, null);
    Assert.isInstanceOfType(
      ADA_LlmProviderFactory.create(),
      ADA_TemplateProvider.class
    );
  }

  @IsTest
  static void theShippedSettingsRecordIsReadWhenThereIsNoOverride() {
    Assert.isNotNull(ADA_LlmProviderFactory.create());
  }

  @IsTest
  static void timeoutsAreClamped() {
    Assert.areEqual(
      ADA_LlmProviderFactory.DEFAULT_TIMEOUT_MS,
      ADA_LlmProviderFactory.timeout(null)
    );
    Assert.areEqual(1000, ADA_LlmProviderFactory.timeout(5));
    Assert.areEqual(10000, ADA_LlmProviderFactory.timeout(10000));
    Assert.areEqual(60000, ADA_LlmProviderFactory.timeout(900000));
  }
}
