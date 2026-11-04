@IsTest
private class ADA_ExplanationCacheTest {
  private static final Datetime MODIFIED = Datetime.newInstanceGmt(
    2026,
    3,
    1,
    10,
    0,
    0
  );

  private static ADA_Explanation answer() {
    ADA_Explanation answer = new ADA_Explanation(
      'Why',
      new List<String>{ 'One', 'Two' },
      'LLM'
    );
    answer.suggestedAction = ADA_SuggestedAction.REQUEST_ACCESS;
    return answer;
  }

  private static ADA_Metadata_Index__c reload() {
    return [
      SELECT Explanation_Json__c, Explained_For__c, Source_Last_Modified__c
      FROM ADA_Metadata_Index__c
      LIMIT 1
    ];
  }

  @IsTest
  static void anExplanationIsStoredAndFoundAgain() {
    insert ADA_LlmTestSupport.indexRow(MODIFIED);
    ADA_ExplanationCache cache = new ADA_ExplanationCache();
    Assert.isNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU'));
    cache.store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
    ADA_Explanation hit = cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU');
    Assert.isNotNull(hit);
    Assert.areEqual('Why', hit.summary);
    Assert.areEqual(2, hit.fixSteps.size());
    Assert.areEqual(ADA_SuggestedAction.REQUEST_ACCESS, hit.suggestedAction);
    Assert.areEqual(MODIFIED, reload().Explained_For__c);
  }

  @IsTest
  static void aChangedComponentInvalidatesTheCache() {
    ADA_Metadata_Index__c row = ADA_LlmTestSupport.indexRow(MODIFIED);
    insert row;
    ADA_ExplanationCache cache = new ADA_ExplanationCache();
    cache.store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
    row.Source_Last_Modified__c = MODIFIED.addDays(1);
    update row;
    Assert.isNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU'));
  }

  @IsTest
  static void anotherLocaleIsAMiss() {
    insert ADA_LlmTestSupport.indexRow(MODIFIED);
    ADA_ExplanationCache cache = new ADA_ExplanationCache();
    cache.store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
    Assert.isNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'fr_FR'));
  }

  @IsTest
  static void anAnswerFromAnOlderPromptIsAMiss() {
    ADA_Metadata_Index__c row = ADA_LlmTestSupport.indexRow(MODIFIED);
    row.Explained_For__c = MODIFIED;
    row.Explanation_Json__c = '{"locale":"en_AU","answer":{"explanation":"Old","fixSteps":["One"],"suggestedAction":"NONE"}}';
    insert row;
    ADA_ExplanationCache cache = new ADA_ExplanationCache();
    Assert.isNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU'));
    cache.store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
    Assert.isNotNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU'));
  }

  @IsTest
  static void aCorruptCacheEntryIsAMissNotAnError() {
    ADA_Metadata_Index__c row = ADA_LlmTestSupport.indexRow(MODIFIED);
    row.Explained_For__c = MODIFIED;
    row.Explanation_Json__c = '{not json';
    insert row;
    Assert.isNull(
      new ADA_ExplanationCache().find(ADA_LlmTestSupport.diagnosis(), 'en_AU')
    );
    row.Explanation_Json__c = '{"locale":"en_AU","answer":{"explanation":"x"}}';
    update row;
    Assert.isNull(
      new ADA_ExplanationCache().find(ADA_LlmTestSupport.diagnosis(), 'en_AU')
    );
  }

  @IsTest
  static void componentsWithoutAnIndexRowOrDateAreNotCached() {
    ADA_ExplanationCache cache = new ADA_ExplanationCache();
    cache.store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
    Assert.isNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU'));
    insert ADA_LlmTestSupport.indexRow(null);
    cache.store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
    Assert.isNull(reload().Explanation_Json__c);
    Assert.isNull(cache.find(ADA_LlmTestSupport.diagnosis(), 'en_AU'));
    Assert.isNull(cache.find(null, 'en_AU'));
    Assert.isNull(cache.find(ADA_Diagnosis.unknown(), 'en_AU'));
  }

  @IsTest
  static void aUserWhoCannotEditTheIndexStillGetsTheCacheWritten() {
    User user = ADA_IndexTestSupport.createUser('adacache', 'ADA_User');
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert ADA_LlmTestSupport.indexRow(MODIFIED);
    }
    System.runAs(user) {
      Assert.isFalse(Schema.SObjectType.ADA_Metadata_Index__c.isUpdateable());
      new ADA_ExplanationCache()
        .store(ADA_LlmTestSupport.diagnosis(), 'en_AU', answer());
      Assert.isNotNull(reload().Explanation_Json__c, 'stored');
      Assert.isNotNull(
        new ADA_ExplanationCache().find(ADA_LlmTestSupport.diagnosis(), 'en_AU')
      );
    }
  }
}
