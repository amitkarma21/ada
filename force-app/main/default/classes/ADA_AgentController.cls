public with sharing class ADA_AgentController {
  public static final String NOT_SURE = 'I\'m not sure what\'s blocking you.';
  public static final String ACTION_EXPLAIN = 'EXPLAIN';
  public static final String ACTION_RAISE_BUG = 'RAISE_BUG';
  private static final Integer MAX_ERROR_TEXT = 4000;
  private static final Integer MAX_QUESTION_INPUT = 2000;
  private static final Integer MAX_NOTES_INPUT = 2000;
  private static final Integer MAX_FORMULA_FIELDS = 40;

  @TestVisible
  private static ADA_IActionTarget targetOverride;

  private static final Map<ADA_ErrorType, String> KIND = new Map<ADA_ErrorType, String>{
    ADA_ErrorType.REQUIRED_FIELD => 'a required field',
    ADA_ErrorType.VALIDATION_RULE => 'a validation rule',
    ADA_ErrorType.DUPLICATE_RULE => 'a duplicate rule',
    ADA_ErrorType.ACCESS => 'an access problem',
    ADA_ErrorType.FLOW => 'a flow',
    ADA_ErrorType.APEX => 'custom code'
  };

  public class DiagnosisView {
    @AuraEnabled
    public String sessionKey;
    @AuraEnabled
    public String errorType;
    @AuraEnabled
    public String headline;
    @AuraEnabled
    public Decimal confidence;
    @AuraEnabled
    public Boolean confident;
    @AuraEnabled
    public String objectApiName;
    @AuraEnabled
    public String componentType;
    @AuraEnabled
    public String componentApiName;
    @AuraEnabled
    public String componentLabel;
    @AuraEnabled
    public List<String> allowedActions;
  }

  public class ExplanationView {
    @AuraEnabled
    public String sessionKey;
    @AuraEnabled
    public String summary;
    @AuraEnabled
    public List<String> fixSteps;
    @AuraEnabled
    public String source;
    @AuraEnabled
    public Boolean cached = false;
    @AuraEnabled
    public Boolean usedFallback = false;
    @AuraEnabled
    public List<String> allowedActions;
  }

  public class ProposalView {
    @AuraEnabled
    public String sessionKey;
    @AuraEnabled
    public String actionType;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String payloadJson;
    @AuraEnabled
    public String notes;
    @AuraEnabled
    public Boolean requiresConfirmation = true;
  }

  public class ConfirmView {
    @AuraEnabled
    public String sessionKey;
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String externalUrl;
    @AuraEnabled
    public Boolean alreadySent = false;
  }

  @AuraEnabled
  public static DiagnosisView diagnose(String errorText, String recordId) {
    if (String.isBlank(errorText)) {
      throw fail('Paste the error message first.');
    }
    ADA_Diagnosis diagnosis = ADA_DiagnosisService.diagnose(
      objectFor(recordId),
      errorText.left(MAX_ERROR_TEXT)
    );
    String key = ADA_AgentSession.newKey();
    ADA_ActionLogger.Entry entry = entryFor(key, diagnosis, 'Diagnose');
    entry.result = ADA_AgentSession.snapshot(diagnosis);
    Boolean confident = isConfident(diagnosis);
    if (!confident) {
      entry.errorSample = ADA_ErrorSampler.sample(errorText);
    }
    ADA_ActionLogger.write(entry);

    DiagnosisView view = new DiagnosisView();
    view.sessionKey = key;
    view.errorType = diagnosis.errorType.name();
    view.confidence = diagnosis.confidence;
    view.confident = confident;
    view.headline = confident ? headline(diagnosis) : NOT_SURE;
    view.objectApiName = diagnosis.objectApiName;
    view.componentType = diagnosis.componentType;
    view.componentApiName = diagnosis.componentApiName;
    view.componentLabel = diagnosis.componentLabel;
    view.allowedActions = allowedActions(diagnosis);
    return view;
  }

  @AuraEnabled
  public static ExplanationView explain(
    String sessionKey,
    String userQuestion
  ) {
    ADA_AgentSession session = load(sessionKey);
    ADA_Diagnosis diagnosis = session.diagnosis;
    ExplanationView view = new ExplanationView();
    view.sessionKey = session.key;
    view.allowedActions = allowedActions(diagnosis);
    ADA_ActionLogger.Entry entry = entryFor(session.key, diagnosis, 'Explain');
    if (!isConfident(diagnosis)) {
      view.summary =
        NOT_SURE +
        ' I can pass the details to your admin team so they can look into it.';
      view.fixSteps = new List<String>();
      view.source = 'None';
      entry.result = 'Not sure: no explanation attempted.';
      ADA_ActionLogger.write(entry);
      return view;
    }
    ADA_ExplanationService.Outcome outcome = ADA_ExplanationService.explain(
      diagnosis,
      extrasFor(diagnosis, userQuestion)
    );
    view.summary = outcome.explanation.summary;
    view.fixSteps = outcome.explanation.fixSteps;
    view.source = outcome.explanation.source;
    view.cached = outcome.cached;
    view.usedFallback = outcome.fallbackReason != null;
    entry.targetSystem = outcome.payloadSent != null ||
      !outcome.blockedKinds.isEmpty()
      ? 'LLM'
      : 'None';
    entry.payloadSent = outcome.payloadSent;
    entry.status = statusFor(outcome);
    entry.result = resultFor(outcome);
    ADA_ActionLogger.write(entry);
    return view;
  }

  @AuraEnabled
  public static ProposalView proposeAction(
    String sessionKey,
    String actionType,
    String userNotes
  ) {
    ADA_AgentSession session = load(sessionKey);
    ADA_Diagnosis diagnosis = session.diagnosis;
    requireAllowed(diagnosis, actionType);
    String notes = notesFrom(userNotes);
    ADA_PayloadBuilder.WorkItemBody body = ADA_PayloadBuilder.forWorkItem(
      diagnosis,
      session.key,
      notes
    );
    ADA_ActionLogger.Entry entry = entryFor(session.key, diagnosis, 'Propose');
    entry.result = 'Proposed ' + actionType + '. Nothing was sent.';
    ADA_ActionLogger.write(entry);

    ProposalView view = new ProposalView();
    view.sessionKey = session.key;
    view.actionType = actionType;
    view.title = body.title;
    view.payloadJson = ADA_PayloadBuilder.toJson(body);
    view.notes = notes;
    return view;
  }

  @AuraEnabled
  public static ConfirmView confirmAction(
    String sessionKey,
    String actionType,
    String userNotes
  ) {
    ADA_AgentSession session = load(sessionKey);
    ADA_Diagnosis diagnosis = session.diagnosis;
    requireAllowed(diagnosis, actionType);
    String idempotencyKey = session.key + ':' + actionType;
    ConfirmView view = new ConfirmView();
    view.sessionKey = session.key;
    ADA_Action_Log__c earlier = ADA_ActionLogger.findSuccess(idempotencyKey);
    if (earlier != null) {
      view.success = true;
      view.status = 'Success';
      view.alreadySent = true;
      view.message = 'This report was already sent. Your admin team has it.';
      view.externalUrl = earlier.External_Url__c;
      return view;
    }
    String payload = ADA_PayloadBuilder.toJson(
      ADA_PayloadBuilder.forWorkItem(
        diagnosis,
        session.key,
        notesFrom(userNotes)
      )
    );
    ADA_ActionResult result = (targetOverride == null
        ? new ADA_EmailTarget()
        : targetOverride)
      .submit(idempotencyKey, payload);

    ADA_ActionLogger.Entry entry = entryFor(session.key, diagnosis, 'Confirm');
    entry.targetSystem = result.target;
    entry.status = result.status;
    entry.result = result.message;
    entry.externalId = result.externalId;
    entry.externalUrl = result.externalUrl;
    entry.payloadSent = result.status == 'Blocked' ? null : payload;
    entry.idempotencyKey = result.success ? idempotencyKey : null;
    ADA_ActionLogger.write(entry);

    view.success = result.success;
    view.status = result.status;
    view.message = result.message;
    view.externalUrl = result.externalUrl;
    return view;
  }

  @AuraEnabled
  public static void recordFeedback(String sessionKey, Boolean solved) {
    ADA_AgentSession session = load(sessionKey);
    if (solved == null) {
      throw fail('Say whether this solved your problem.');
    }
    ADA_ActionLogger.Entry entry = entryFor(
      session.key,
      session.diagnosis,
      'Feedback'
    );
    entry.feedback = solved ? 'Solved' : 'Not solved';
    entry.idempotencyKey = session.key + ':Feedback';
    ADA_ActionLogger.write(entry);
  }

  @TestVisible
  private static String statusFor(ADA_ExplanationService.Outcome outcome) {
    if (!outcome.blockedKinds.isEmpty()) {
      return 'Blocked';
    }
    return outcome.fallbackReason == null ? 'Success' : 'Fallback';
  }

  private static String resultFor(ADA_ExplanationService.Outcome outcome) {
    List<String> parts = new List<String>{
      'Answered by ' + outcome.explanation.source
    };
    if (outcome.cached) {
      parts.add('from cache');
    }
    if (!outcome.blockedKinds.isEmpty()) {
      parts.add(
        'blocked: ' + String.join(new List<String>(outcome.blockedKinds), ', ')
      );
    }
    if (outcome.fallbackReason != null) {
      parts.add('fallback reason: ' + outcome.fallbackReason);
    }
    return String.join(parts, '; ');
  }

  private static void requireAllowed(
    ADA_Diagnosis diagnosis,
    String actionType
  ) {
    if (
      actionType != ACTION_RAISE_BUG ||
      !allowedActions(diagnosis).contains(actionType)
    ) {
      throw fail('That action is not available.');
    }
  }

  private static String notesFrom(String userNotes) {
    return userNotes == null ? '' : userNotes.left(MAX_NOTES_INPUT);
  }

  private static ADA_AgentSession load(String sessionKey) {
    try {
      return ADA_AgentSession.load(sessionKey);
    } catch (ADA_AgentSession.SessionException missing) {
      throw fail('Session not found. Start again.');
    }
  }

  private static ADA_ActionLogger.Entry entryFor(
    String key,
    ADA_Diagnosis diagnosis,
    String step
  ) {
    ADA_ActionLogger.Entry entry = new ADA_ActionLogger.Entry();
    entry.sessionKey = key;
    entry.step = step;
    entry.errorType = diagnosis.errorType.name();
    entry.componentApiName = diagnosis.componentApiName;
    entry.objectApiName = diagnosis.objectApiName;
    entry.confidence = diagnosis.confidence;
    return entry;
  }

  private static Boolean isConfident(ADA_Diagnosis diagnosis) {
    return diagnosis.isConfident(ADA_DiagnosisService.threshold());
  }

  private static List<String> allowedActions(ADA_Diagnosis diagnosis) {
    return isConfident(diagnosis)
      ? new List<String>{ ACTION_EXPLAIN, ACTION_RAISE_BUG }
      : new List<String>{ ACTION_RAISE_BUG };
  }

  private static String headline(ADA_Diagnosis diagnosis) {
    String kind = KIND.get(diagnosis.errorType);
    String text = 'This looks like ' + (kind == null ? 'a problem' : kind);
    if (String.isNotBlank(diagnosis.componentLabel)) {
      text += ': ' + diagnosis.componentLabel;
    }
    return text + '.';
  }

  private static ADA_PayloadBuilder.Extras extrasFor(
    ADA_Diagnosis diagnosis,
    String userQuestion
  ) {
    ADA_PayloadBuilder.Extras extras = new ADA_PayloadBuilder.Extras();
    extras.objectLabel = objectLabel(diagnosis.objectApiName);
    extras.userQuestion = userQuestion == null
      ? null
      : userQuestion.left(MAX_QUESTION_INPUT);
    extras.locale = UserInfo.getLocale();
    ADA_Metadata_Index__c row = indexRow(diagnosis);
    if (row != null) {
      extras.conditionFormulaMasked = row.Formula_Masked__c;
      extras.ruleMessage = diagnosis.runtimeFault == true
        ? null
        : row.Message_Template__c;
      extras.flowRunsWhen = row.Flow_Runs_When__c;
    }
    for (String fieldName : diagnosis.fieldApiNames) {
      String label = fieldLabel(diagnosis.objectApiName, fieldName);
      if (label != null) {
        extras.fieldLabels.add(label);
        extras.fieldLabelsByApiName.put(fieldName, label);
      }
    }
    for (String word : formulaWords(extras.conditionFormulaMasked)) {
      if (!extras.fieldLabelsByApiName.containsKey(word)) {
        String label = fieldLabel(diagnosis.objectApiName, word);
        if (label != null) {
          extras.fieldLabelsByApiName.put(word, label);
        }
      }
    }
    return extras;
  }

  private static Set<String> formulaWords(String maskedFormula) {
    Set<String> names = new Set<String>();
    if (String.isBlank(maskedFormula)) {
      return names;
    }
    Matcher words = Pattern.compile('[A-Za-z][A-Za-z0-9_]*')
      .matcher(maskedFormula);
    while (words.find() && names.size() < MAX_FORMULA_FIELDS) {
      names.add(words.group());
    }
    return names;
  }

  private static ADA_Metadata_Index__c indexRow(ADA_Diagnosis diagnosis) {
    if (
      String.isBlank(diagnosis.componentApiName) ||
      String.isBlank(diagnosis.componentType)
    ) {
      return null;
    }
    for (
      ADA_Metadata_Index__c row : new ADA_ObjectIndexStore()
        .forObjectAndType(diagnosis.objectApiName, diagnosis.componentType)
    ) {
      if (row.Api_Name__c == diagnosis.componentApiName) {
        return row;
      }
    }
    return null;
  }

  private static String objectFor(String recordId) {
    if (String.isBlank(recordId)) {
      return null;
    }
    try {
      return Id.valueOf(recordId)
        .getSObjectType()
        .getDescribe(SObjectDescribeOptions.DEFERRED)
        .getName();
    } catch (Exception notAnId) {
      return null;
    }
  }

  private static Schema.DescribeSObjectResult describe(String objectApiName) {
    if (String.isBlank(objectApiName)) {
      return null;
    }
    try {
      Type objectType = Type.forName(objectApiName);
      if (objectType == null) {
        return null;
      }
      return ((SObject) objectType.newInstance())
        .getSObjectType()
        .getDescribe(SObjectDescribeOptions.DEFERRED);
    } catch (Exception unknownObject) {
      return null;
    }
  }

  private static String objectLabel(String objectApiName) {
    Schema.DescribeSObjectResult described = describe(objectApiName);
    return described == null ? objectApiName : described.getLabel();
  }

  private static String fieldLabel(String objectApiName, String fieldName) {
    Schema.DescribeSObjectResult described = describe(objectApiName);
    if (described == null) {
      return null;
    }
    Schema.SObjectField field = described.fields.getMap().get(fieldName);
    return field == null ? null : field.getDescribe().getLabel();
  }

  private static AuraHandledException fail(String message) {
    AuraHandledException problem = new AuraHandledException(message);
    problem.setMessage(message);
    return problem;
  }
}
