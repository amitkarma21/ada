public with sharing class ADA_LlmProviderFactory {
  public static final String OPENAI_COMPATIBLE = 'OpenAICompatible';
  public static final Integer DEFAULT_TIMEOUT_MS = 10000;
  public static final Integer MIN_TIMEOUT_MS = 1000;
  public static final Integer MAX_TIMEOUT_MS = 60000;

  @TestVisible
  private static ADA_Setting__mdt settingOverride;

  public static ADA_ILlmProvider create() {
    ADA_Setting__mdt setting = settingOverride != null
      ? settingOverride
      : ADA_Setting__mdt.getInstance('Default');
    if (
      setting != null &&
      setting.LLM_Provider__c == OPENAI_COMPATIBLE &&
      !String.isBlank(setting.LLM_Model__c)
    ) {
      return new ADA_OpenAiCompatibleProvider(
        setting.LLM_Model__c.trim(),
        timeout(setting.LLM_Timeout_Ms__c)
      );
    }
    return new ADA_TemplateProvider();
  }

  public static Integer timeout(Decimal configured) {
    if (configured == null) {
      return DEFAULT_TIMEOUT_MS;
    }
    Integer value = configured.intValue();
    return Math.max(MIN_TIMEOUT_MS, Math.min(MAX_TIMEOUT_MS, value));
  }
}
