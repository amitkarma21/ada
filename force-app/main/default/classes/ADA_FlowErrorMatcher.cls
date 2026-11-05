public with sharing class ADA_FlowErrorMatcher extends ADA_TemplateMatcher {
  public static final Decimal FAULT_CONFIDENCE = 0.9;
  private static final Integer MIN_LABEL_WORDS = 2;
  private static final Integer MIN_API_NAME = 3;

  // Wordings Salesforce itself uses when a flow fails at run time. A flow's own custom error
  // is not here: that text is the admin's and is matched against the index instead.
  private static final Pattern FAULT = Pattern.compile(
    '(?is)unhandled fault has occurred|flow_element_error|\\bflow interview\\b|' +
      'error element\\s+\\w+\\s*\\(Flow\\w+\\)|the flow (?:tried|failed) to|' +
      'error occurred during flow|flow api name'
  );
  private static final Pattern STEP = Pattern.compile(
    '(?is)error element\\s+([A-Za-z0-9_]{1,80})\\s*\\((Flow[A-Za-z]+)\\)'
  );
  private static final Map<String, String> STEP_KINDS = new Map<String, String>{
    'flowrecordcreate' => 'creating a record',
    'flowrecordupdate' => 'updating records',
    'flowrecordlookup' => 'looking up records',
    'flowrecorddelete' => 'deleting records',
    'flowactioncall' => 'running an action',
    'flowsubflow' => 'running a subflow',
    'flowloop' => 'looping over records'
  };

  public ADA_FlowErrorMatcher() {
    super(ADA_ErrorType.FLOW, ADA_MetadataIndexer.FLOW);
  }

  public override ADA_Diagnosis match(ADA_ErrorContext context) {
    ADA_Diagnosis indexed = super.match(context);
    if (indexed != null && indexed.confidence >= FAULT_CONFIDENCE) {
      return indexed;
    }
    if (!context.hasMessage() || !FAULT.matcher(context.rawMessage).find()) {
      return indexed;
    }
    return fault(context);
  }

  private static ADA_Diagnosis fault(ADA_ErrorContext context) {
    ADA_Diagnosis diagnosis = new ADA_Diagnosis(
      ADA_ErrorType.FLOW,
      FAULT_CONFIDENCE
    );
    diagnosis.objectApiName = context.objectApiName;
    diagnosis.componentType = ADA_MetadataIndexer.FLOW;
    ADA_Metadata_Index__c named = namedFlow(context);
    List<String> notes = new List<String>();
    if (named != null) {
      diagnosis.componentApiName = named.Api_Name__c;
      diagnosis.componentLabel = named.Label__c;
      if (String.isNotBlank(named.Description__c)) {
        notes.add(named.Description__c);
      }
    }
    String step = stepNote(context.rawMessage);
    if (step != null) {
      notes.add(step);
    }
    if (!notes.isEmpty()) {
      diagnosis.description = String.join(notes, ' ');
    }
    return diagnosis;
  }

  // A flow is named only when the message carries its API name or a label of two or more
  // words, and only one flow fits best. The longer name wins; a tie names nothing.
  private static ADA_Metadata_Index__c namedFlow(ADA_ErrorContext context) {
    String raw = context.rawMessage.toLowerCase();
    String words = ' ' + context.normalisedMessage + ' ';
    ADA_Metadata_Index__c best;
    Integer bestLength = 0;
    Boolean tied = false;
    for (
      ADA_Metadata_Index__c row : context.activeRows(ADA_MetadataIndexer.FLOW)
    ) {
      Integer length = nameLength(row, raw, words);
      if (length > bestLength) {
        best = row;
        bestLength = length;
        tied = false;
      } else if (length > 0 && length == bestLength) {
        tied = true;
      }
    }
    return tied ? null : best;
  }

  private static Integer nameLength(
    ADA_Metadata_Index__c row,
    String raw,
    String words
  ) {
    Integer length = 0;
    String api = String.isBlank(row.Api_Name__c)
      ? ''
      : row.Api_Name__c.toLowerCase();
    if (api.length() >= MIN_API_NAME && hasToken(raw, api)) {
      length = api.length();
    }
    String label = ADA_MessageNormaliser.normalise(row.Label__c);
    if (
      label.split(' ').size() >= MIN_LABEL_WORDS &&
      words.contains(' ' + label + ' ')
    ) {
      length = Math.max(length, label.length());
    }
    return length;
  }

  private static Boolean hasToken(String text, String token) {
    Integer at = text.indexOf(token);
    while (at >= 0) {
      Integer after = at + token.length();
      if (
        (at == 0 || !isNameChar(text.substring(at - 1, at))) &&
        (after == text.length() ||
        !isNameChar(text.substring(after, after + 1)))
      ) {
        return true;
      }
      at = text.indexOf(token, at + 1);
    }
    return false;
  }

  private static Boolean isNameChar(String character) {
    return character == '_' ||
      character.isAlphanumeric() && character.isAsciiPrintable();
  }

  // Only the step's name and kind. What follows in the message may hold record values.
  private static String stepNote(String rawMessage) {
    Matcher found = STEP.matcher(rawMessage);
    if (!found.find()) {
      return null;
    }
    String kind = STEP_KINDS.get(found.group(2).toLowerCase());
    return 'The flow stopped at the step "' +
      found.group(1) +
      '"' +
      (kind == null ? '' : ' (' + kind + ')') +
      '.';
  }
}
