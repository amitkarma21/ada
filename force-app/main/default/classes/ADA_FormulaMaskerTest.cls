@IsTest
private class ADA_FormulaMaskerTest {
  @IsTest
  static void masksTextAndIdsInTheSpecExample() {
    String masked = ADA_FormulaMasker.mask(
      'Account.Name = \'Acme Pty Ltd\' && OwnerId = \'005000000000001AAA\''
    );
    Assert.areEqual('Account.Name = \'TEXT_1\' && OwnerId = \'ID_1\'', masked);
  }

  @IsTest
  static void masksBareIdsAsIdPlaceholders() {
    String masked = ADA_FormulaMasker.mask(
      'OwnerId = 005000000000001AAA && RecordTypeId = 012000000000002'
    );
    Assert.areEqual('OwnerId = ID_1 && RecordTypeId = ID_2', masked);
  }

  @IsTest
  static void sameLiteralGetsTheSamePlaceholder() {
    Assert.areEqual(
      'OR(Type = \'TEXT_1\', Industry = \'TEXT_2\', Type = \'TEXT_1\')',
      ADA_FormulaMasker.mask(
        'OR(Type = \'Gold\', Industry = \'Retail\', Type = \'Gold\')'
      )
    );
  }

  @IsTest
  static void masksDoubleQuotedAndEscapedLiterals() {
    Assert.areEqual(
      'Name = "TEXT_1" && Title = \'TEXT_2\'',
      ADA_FormulaMasker.mask(
        'Name = "Jane \\"JJ\\" Doe" && Title = \'O\\\'Brien\''
      )
    );
  }

  @IsTest
  static void leavesNamesNumbersAndFunctionsAlone() {
    String formula = 'AND(NOT(IsClosed), Amount > 100000, OpportunityName <> null)';
    Assert.areEqual(formula, ADA_FormulaMasker.mask(formula));
  }

  @IsTest
  static void leavesLongNamesWithoutDigitsAlone() {
    Assert.areEqual(
      'LEN(AccountOwnerNameXYZ) > 3',
      ADA_FormulaMasker.mask('LEN(AccountOwnerNameXYZ) > 3')
    );
    Assert.areEqual(
      'OpportunityName = null',
      ADA_FormulaMasker.mask('OpportunityName = null')
    );
  }

  @IsTest
  static void blankInputComesBackBlank() {
    Assert.isNull(ADA_FormulaMasker.mask(null));
    Assert.areEqual('', ADA_FormulaMasker.mask(''));
  }

  @IsTest
  static void listsReferencedFieldsInOrderWithoutDuplicates() {
    String fields = ADA_FormulaMasker.referencedFields(
      'AND(NOT(IsClosed), CloseDate < TODAY(), Owner.Name = \'TEXT_1\', ISBLANK(CloseDate), $User.Id = null, ID_1 = Id, TRUE)'
    );
    Assert.areEqual('IsClosed,CloseDate,Owner.Name,Id', fields);
  }

  @IsTest
  static void noFieldsGivesBlank() {
    Assert.areEqual('', ADA_FormulaMasker.referencedFields('TRUE'));
    Assert.areEqual('', ADA_FormulaMasker.referencedFields(null));
  }
}
