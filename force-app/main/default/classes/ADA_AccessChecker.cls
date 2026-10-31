public with sharing class ADA_AccessChecker implements ADA_IMatcher {
  public static final Decimal WITH_FIELDS = 0.95;
  public static final Decimal WITHOUT_FIELDS = 0.9;

  private static final Pattern FIELD_NAMES = Pattern.compile(
    '(?is)fieldNames:\\s*([A-Za-z0-9_,\\s]+)'
  );
  private static final Pattern FIELD_NAME = Pattern.compile('[A-Za-z0-9_]+');
  private static final List<String> WORDINGS = new List<String>{
    'insufficient access',
    'fields being inaccessible',
    'inaccessible on sobject',
    'you do not have the level of access',
    'you dont have access to'
  };

  public ADA_Diagnosis match(ADA_ErrorContext context) {
    if (!context.hasMessage() || !signalled(context)) {
      return null;
    }
    List<String> fields = parseFields(context.rawMessage);
    ADA_Diagnosis diagnosis = new ADA_Diagnosis(
      ADA_ErrorType.ACCESS,
      fields.isEmpty() ? WITHOUT_FIELDS : WITH_FIELDS
    );
    diagnosis.objectApiName = context.objectApiName;
    diagnosis.fieldApiNames = fields;
    diagnosis.suggestedAction = ADA_SuggestedAction.REQUEST_ACCESS;
    diagnosis.componentType = fields.isEmpty() ? 'Object' : 'Field';
    if (fields.size() == 1) {
      diagnosis.componentApiName = fields[0];
      diagnosis.componentLabel = fieldLabel(context.objectApiName, fields[0]);
    }
    return diagnosis;
  }

  private static Boolean signalled(ADA_ErrorContext context) {
    for (String wording : WORDINGS) {
      if (context.normalisedMessage.contains(wording)) {
        return true;
      }
    }
    return false;
  }

  private static List<String> parseFields(String raw) {
    List<String> fields = new List<String>();
    Matcher found = FIELD_NAMES.matcher(raw);
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

  private static String fieldLabel(String objectApiName, String fieldApiName) {
    try {
      Type objectType = Type.forName(objectApiName);
      if (objectType == null) {
        return null;
      }
      Schema.SObjectType sobjectType = ((SObject) objectType.newInstance())
        .getSObjectType();
      Schema.DescribeSObjectResult described = sobjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      );
      Schema.SObjectField field = described.fields.getMap().get(fieldApiName);
      return field == null ? null : field.getDescribe().getLabel();
    } catch (Exception e) {
      return null;
    }
  }
}
