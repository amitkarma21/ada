@IsTest
private class ADA_Demo_AccessErrorTest {
  @TestSetup
  static void setup() {
    Profile standard = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    insert new User(
      Alias = 'adademo',
      Email = 'ada.demo.user@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Demo',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standard.Id,
      TimeZoneSidKey = 'Australia/Melbourne',
      UserName = 'ada.demo.user.' + System.currentTimeMillis() + '@example.com'
    );
    insert new Opportunity(
      Name = 'Access demo',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
  }

  @IsTest
  static void standardUserCannotWriteRestrictedNotes() {
    User demoUser = [SELECT Id FROM User WHERE Alias = 'adademo' LIMIT 1];
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    opp.ADA_Demo_Internal_Notes__c = 'x';
    Database.SaveResult result;

    System.runAs(demoUser) {
      result = Database.update(opp, false, AccessLevel.USER_MODE);
    }

    Assert.isFalse(result.isSuccess());
    Database.Error error = result.getErrors()[0];
    Assert.areEqual(
      StatusCode.CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY,
      error.getStatusCode()
    );
    Assert.areEqual(
      'Operation failed due to fields being inaccessible on Sobject Opportunity, check errors on Exception or Result!  fieldNames: ADA_Demo_Internal_Notes__c',
      error.getMessage(),
      'Keep test-data/golden-errors.json (opp-no-field-access) in step with this wording'
    );
  }
}
