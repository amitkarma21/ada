public with sharing class ADA_RequiredFieldMatcher implements ADA_IMatcher {
  public static final Decimal CONFIRMED = 0.98;
  public static final Decimal SIGNALLED = 0.9;

  private static final Pattern MISSING_LIST = Pattern.compile(
    '(?is)required fields? (?:are|is) missing\\s*:?\\s*\\[([^\\]]*)\\]'
  );
  private static final Pattern FIELD_NAME = Pattern.compile('[A-Za-z0-9_]+');
  private static final Set<String> SIGNALS = new Set<String>{
    'required fields are missing',
    'required field is missing',
    'required field missing',
    'complete this field',
    'you must enter a value'
  };

  public ADA_Diagnosis match(ADA_ErrorContext context) {
    if (!context.hasMessage() || !signalled(context)) {
      return null;
    }
    List<String> fields = parseFields(context.rawMessage);
    ADA_Diagnosis diagnosis = new ADA_Diagnosis(
      ADA_ErrorType.REQUIRED_FIELD,
      confirmed(context, fields) ? CONFIRMED : SIGNALLED
    );
    diagnosis.objectApiName = context.objectApiName;
    diagnosis.componentType = ADA_MetadataIndexer.REQUIRED_FIELD;
    diagnosis.fieldApiNames = fields;
    return diagnosis;
  }

  private static Boolean signalled(ADA_ErrorContext context) {
    if (context.rawMessage.containsIgnoreCase('REQUIRED_FIELD_MISSING')) {
      return true;
    }
    for (String signal : SIGNALS) {
      if (context.normalisedMessage.startsWith(signal)) {
        return true;
      }
    }
    return false;
  }

  private static List<String> parseFields(String raw) {
    List<String> fields = new List<String>();
    Matcher found = MISSING_LIST.matcher(raw);
    if (!found.find()) {
      return fields;
    }
    for (String name : found.group(1).split(',')) {
      String trimmed = name.trim();
      if (FIELD_NAME.matcher(trimmed).matches()) {
        fields.add(trimmed);
      }
    }
    return fields;
  }

  private static Boolean confirmed(
    ADA_ErrorContext context,
    List<String> fields
  ) {
    if (fields.isEmpty()) {
      return false;
    }
    Set<String> known = new Set<String>();
    for (
      ADA_Metadata_Index__c row : context.rows(
        ADA_MetadataIndexer.REQUIRED_FIELD
      )
    ) {
      if (!String.isBlank(row.Field_Api_Names__c)) {
        for (String name : row.Field_Api_Names__c.split(',')) {
          known.add(name.trim().toLowerCase());
        }
      }
    }
    for (String field : fields) {
      if (!known.contains(field.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}
