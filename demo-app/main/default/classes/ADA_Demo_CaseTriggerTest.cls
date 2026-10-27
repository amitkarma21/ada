@IsTest
private class ADA_Demo_CaseTriggerTest {
  @IsTest
  static void webCaseWithoutOriginIsBlocked() {
    Case c = new Case(
      Subject = 'Web case',
      SuppliedEmail = 'web.user@example.com'
    );

    Test.startTest();
    Database.SaveResult result = Database.insert(c, false);
    Test.stopTest();

    Assert.isFalse(result.isSuccess());
    Assert.areEqual(
      'Cases that arrive from the web must have an Origin.',
      result.getErrors()[0].getMessage()
    );
  }

  @IsTest
  static void webCaseWithOriginIsSaved() {
    Case c = new Case(
      Subject = 'Web case',
      SuppliedEmail = 'web.user@example.com',
      Origin = 'Web'
    );

    Test.startTest();
    Database.SaveResult result = Database.insert(c, false);
    Test.stopTest();

    Assert.isTrue(result.isSuccess());
  }
}
