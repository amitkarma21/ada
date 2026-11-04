@IsTest
private class ADA_ActionLoggerTest {
  @TestSetup
  static void setup() {
    ADA_IndexTestSupport.createUser('adalog1', 'ADA_User');
    ADA_IndexTestSupport.createUser('adalog2', 'ADA_User');
  }

  private static User userByAlias(String alias) {
    return [SELECT Id FROM User WHERE Alias = :alias LIMIT 1];
  }

  private static ADA_ActionLogger.Entry entry(String step) {
    ADA_ActionLogger.Entry entry = new ADA_ActionLogger.Entry();
    entry.sessionKey = 'session-1';
    entry.step = step;
    entry.errorType = 'VALIDATION_RULE';
    entry.componentApiName = 'Close_Date_Rule';
    entry.confidence = 0.98;
    return entry;
  }

  @IsTest
  static void aUserWritesAnOwnRowThroughTheLogger() {
    System.runAs(userByAlias('adalog1')) {
      ADA_Action_Log__c row = ADA_ActionLogger.write(entry('Diagnose'));
      Assert.isNotNull(row.Id);
      ADA_Action_Log__c stored = [
        SELECT
          OwnerId,
          Session_Key__c,
          Step__c,
          Error_Type__c,
          Component_Api_Name__c,
          Confidence__c,
          Target_System__c,
          Status__c
        FROM ADA_Action_Log__c
        WHERE Id = :row.Id
        WITH USER_MODE
      ];
      Assert.areEqual(UserInfo.getUserId(), stored.OwnerId);
      Assert.areEqual('session-1', stored.Session_Key__c);
      Assert.areEqual('Diagnose', stored.Step__c);
      Assert.areEqual('VALIDATION_RULE', stored.Error_Type__c);
      Assert.areEqual('Close_Date_Rule', stored.Component_Api_Name__c);
      Assert.areEqual(0.98, stored.Confidence__c);
      Assert.areEqual('None', stored.Target_System__c);
      Assert.areEqual('Success', stored.Status__c);
    }
  }

  @IsTest
  static void anotherUserCannotSeeTheRow() {
    System.runAs(userByAlias('adalog1')) {
      ADA_ActionLogger.write(entry('Diagnose'));
    }
    System.runAs(userByAlias('adalog2')) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM ADA_Action_Log__c WITH USER_MODE]
      );
    }
  }

  @IsTest
  static void aUserCannotInsertARowDirectly() {
    System.runAs(userByAlias('adalog1')) {
      try {
        Database.insert(
          new ADA_Action_Log__c(Step__c = 'Diagnose'),
          AccessLevel.USER_MODE
        );
        Assert.fail('A direct insert must be denied');
      } catch (System.TypeException e) {
        Assert.isTrue(e.getMessage().contains('not allowed'));
      }
    }
  }

  @IsTest
  static void longTextIsClippedInsteadOfFailing() {
    ADA_ActionLogger.Entry long1 = entry('Explain');
    long1.payloadSent = 'p'.repeat(140000);
    long1.result = 'r'.repeat(5000);
    ADA_Action_Log__c row = ADA_ActionLogger.write(long1);
    ADA_Action_Log__c stored = [
      SELECT Payload_Sent__c, Result__c
      FROM ADA_Action_Log__c
      WHERE Id = :row.Id
    ];
    Assert.areEqual(
      ADA_ActionLogger.MAX_PAYLOAD,
      stored.Payload_Sent__c.length()
    );
    Assert.areEqual(ADA_ActionLogger.MAX_RESULT, stored.Result__c.length());
  }

  @IsTest
  static void aRepeatedIdempotencyKeyReturnsTheExistingRow() {
    ADA_ActionLogger.Entry first = entry('Feedback');
    first.idempotencyKey = 'session-1:Feedback';
    first.feedback = 'Solved';
    ADA_Action_Log__c one = ADA_ActionLogger.write(first);
    ADA_ActionLogger.Entry again = entry('Feedback');
    again.idempotencyKey = 'session-1:Feedback';
    again.feedback = 'Not solved';
    ADA_Action_Log__c two = ADA_ActionLogger.write(again);
    Assert.areEqual(one.Id, two.Id);
    Assert.areEqual(1, [SELECT COUNT() FROM ADA_Action_Log__c]);
    Assert.areEqual(
      'Solved',
      [SELECT Feedback__c FROM ADA_Action_Log__c LIMIT 1].Feedback__c
    );
  }

  @IsTest
  static void findSuccessSeesOnlyTheOwnersSuccessfulRowForTheKey() {
    System.runAs(userByAlias('adalog1')) {
      Assert.isNull(ADA_ActionLogger.findSuccess(null));
      Assert.isNull(ADA_ActionLogger.findSuccess('  '));
      Assert.isNull(ADA_ActionLogger.findSuccess('send-1'));

      ADA_ActionLogger.Entry done = entry('Confirm');
      done.idempotencyKey = 'send-1';
      done.externalId = '42';
      ADA_ActionLogger.write(done);
      ADA_ActionLogger.Entry failed = entry('Confirm');
      failed.idempotencyKey = 'send-2';
      failed.status = 'Failed';
      ADA_ActionLogger.write(failed);

      ADA_Action_Log__c found = ADA_ActionLogger.findSuccess('send-1');
      Assert.isNotNull(found);
      Assert.areEqual('42', found.External_Id__c);
      Assert.isNull(ADA_ActionLogger.findSuccess('send-2'));
    }
    System.runAs(userByAlias('adalog2')) {
      Assert.isNull(ADA_ActionLogger.findSuccess('send-1'));
    }
  }

  @IsTest
  static void aMissingStepIsRejected() {
    ADA_ActionLogger.Entry bad = entry(null);
    try {
      ADA_ActionLogger.write(bad);
      Assert.fail('A row needs a step');
    } catch (ADA_ActionLogger.LogException e) {
      Assert.isTrue(e.getMessage().contains('step'));
    }
    try {
      ADA_ActionLogger.write(null);
      Assert.fail('A null entry is rejected');
    } catch (ADA_ActionLogger.LogException e) {
      Assert.isTrue(e.getMessage().contains('step'));
    }
  }
}
