@IsTest
private class ADA_AgentSessionTest {
  @TestSetup
  static void setup() {
    ADA_IndexTestSupport.createUser('adases1', 'ADA_User');
    ADA_IndexTestSupport.createUser('adases2', 'ADA_User');
    ADA_IndexTestSupport.createUser('adasesa', 'ADA_Admin');
  }

  private static User userByAlias(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  private static String start(ADA_Diagnosis diagnosis) {
    String key = ADA_AgentSession.newKey();
    ADA_ActionLogger.Entry entry = new ADA_ActionLogger.Entry();
    entry.sessionKey = key;
    entry.step = 'Diagnose';
    entry.result = ADA_AgentSession.snapshot(diagnosis);
    ADA_ActionLogger.write(entry);
    return key;
  }

  @IsTest
  static void keysAreLongRandomAndDifferent() {
    Set<String> keys = new Set<String>();
    for (Integer i = 0; i < 20; i++) {
      String key = ADA_AgentSession.newKey();
      Assert.areEqual(32, key.length());
      Assert.isTrue(Pattern.matches('[0-9a-f]{32}', key));
      keys.add(key);
    }
    Assert.areEqual(20, keys.size());
  }

  @IsTest
  static void theSnapshotRoundTripsEveryField() {
    ADA_Diagnosis original = ADA_LlmTestSupport.diagnosis();
    original.fieldApiNames = new List<String>{ 'CloseDate', 'StageName' };
    original.suggestedAction = ADA_SuggestedAction.REQUEST_ACCESS;
    System.runAs(userByAlias('adases1')) {
      String key = start(original);
      ADA_AgentSession session = ADA_AgentSession.load(key);
      Assert.areEqual(key, session.key);
      ADA_Diagnosis copy = session.diagnosis;
      Assert.areEqual(original.errorType, copy.errorType);
      Assert.areEqual(original.confidence, copy.confidence);
      Assert.areEqual(original.objectApiName, copy.objectApiName);
      Assert.areEqual(original.componentType, copy.componentType);
      Assert.areEqual(original.componentApiName, copy.componentApiName);
      Assert.areEqual(original.componentLabel, copy.componentLabel);
      Assert.areEqual(original.description, copy.description);
      Assert.areEqual(original.fieldApiNames, copy.fieldApiNames);
      Assert.areEqual(original.suggestedAction, copy.suggestedAction);
    }
  }

  @IsTest
  static void theSnapshotStaysUnderTheFieldLimit() {
    ADA_Diagnosis big = ADA_LlmTestSupport.diagnosis();
    big.description = 'd'.repeat(3000);
    big.componentLabel = 'l'.repeat(500);
    big.fieldApiNames = new List<String>();
    for (Integer i = 0; i < 100; i++) {
      big.fieldApiNames.add('Field_' + i + '_' + 'x'.repeat(200));
    }
    String snapshot = ADA_AgentSession.snapshot(big);
    Assert.isTrue(snapshot.length() <= ADA_ActionLogger.MAX_RESULT);
    System.runAs(userByAlias('adases1')) {
      ADA_AgentSession session = ADA_AgentSession.load(start(big));
      Assert.areEqual(
        ADA_AgentSession.MAX_FIELDS,
        session.diagnosis.fieldApiNames.size()
      );
    }
  }

  @IsTest
  static void anotherUserCannotLoadTheSession() {
    String key;
    System.runAs(userByAlias('adases1')) {
      key = start(ADA_LlmTestSupport.diagnosis());
    }
    System.runAs(userByAlias('adases2')) {
      assertNotFound(key);
    }
  }

  @IsTest
  static void anAdminWhoCanSeeEveryLogStillCannotLoadAnothersSession() {
    String key;
    System.runAs(userByAlias('adases1')) {
      key = start(ADA_LlmTestSupport.diagnosis());
    }
    System.runAs(userByAlias('adasesa')) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM ADA_Action_Log__c WITH USER_MODE],
        'the admin can read the log row'
      );
      assertNotFound(key);
    }
  }

  @IsTest
  static void unknownOrMalformedKeysAreNotFound() {
    System.runAs(userByAlias('adases1')) {
      for (
        String key : new List<String>{
          null,
          '',
          '   ',
          'nope',
          '0'.repeat(32),
          'x'.repeat(65),
          '\' OR Id != null --'
        }
      ) {
        assertNotFound(key);
      }
    }
  }

  @IsTest
  static void onlyTheDiagnoseRowCarriesTheState() {
    System.runAs(userByAlias('adases1')) {
      String key = ADA_AgentSession.newKey();
      ADA_ActionLogger.Entry entry = new ADA_ActionLogger.Entry();
      entry.sessionKey = key;
      entry.step = 'Explain';
      entry.result = ADA_AgentSession.snapshot(ADA_LlmTestSupport.diagnosis());
      ADA_ActionLogger.write(entry);
      assertNotFound(key);
    }
  }

  @IsTest
  static void aDamagedSnapshotIsNotFound() {
    System.runAs(userByAlias('adases1')) {
      for (
        String damaged : new List<String>{
          '{not json',
          '{"errorType":"NOT_A_TYPE","confidence":1}',
          '{"confidence":1}',
          ''
        }
      ) {
        String damagedKey = ADA_AgentSession.newKey();
        ADA_ActionLogger.Entry entry = new ADA_ActionLogger.Entry();
        entry.sessionKey = damagedKey;
        entry.step = 'Diagnose';
        entry.result = damaged;
        ADA_ActionLogger.write(entry);
        assertNotFound(damagedKey);
      }
    }
  }

  private static void assertNotFound(String key) {
    try {
      ADA_AgentSession.load(key);
      Assert.fail('Session should not load: ' + key);
    } catch (ADA_AgentSession.SessionException e) {
      Assert.isTrue(e.getMessage().contains('not found'));
    }
  }
}
