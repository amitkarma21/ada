public with sharing class ADA_AgentSession {
  public static final Integer MAX_FIELDS = 20;
  private static final Integer MAX_FIELD_NAME = 80;
  private static final Integer MAX_LABEL = 120;
  private static final Integer MAX_DESCRIPTION = 500;
  private static final Pattern KEY_SHAPE = Pattern.compile('[0-9a-f]{32}');

  public class SessionException extends Exception {
  }

  // What the Diagnose log row remembers. No error text, no record values.
  private class State {
    public String errorType;
    public Decimal confidence;
    public String objectApiName;
    public String componentType;
    public String componentApiName;
    public String componentLabel;
    public String description;
    public List<String> fieldApiNames;
    public String suggestedAction;
  }

  public final String key;
  public final ADA_Diagnosis diagnosis;

  private ADA_AgentSession(String key, ADA_Diagnosis diagnosis) {
    this.key = key;
    this.diagnosis = diagnosis;
  }

  public static String newKey() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
  }

  public static String snapshot(ADA_Diagnosis diagnosis) {
    State state = new State();
    state.errorType = diagnosis.errorType.name();
    state.confidence = diagnosis.confidence;
    state.objectApiName = diagnosis.objectApiName;
    state.componentType = diagnosis.componentType;
    state.componentApiName = diagnosis.componentApiName;
    state.componentLabel = clip(diagnosis.componentLabel, MAX_LABEL);
    state.description = clip(diagnosis.description, MAX_DESCRIPTION);
    state.fieldApiNames = new List<String>();
    for (String name : diagnosis.fieldApiNames) {
      if (state.fieldApiNames.size() == MAX_FIELDS) {
        break;
      }
      state.fieldApiNames.add(clip(name, MAX_FIELD_NAME));
    }
    state.suggestedAction = diagnosis.suggestedAction.name();
    return JSON.serialize(state, true);
  }

  // The client only ever holds the key. The state comes from the caller's own Diagnose
  // row; the owner filter also stops an admin who can read every log from using it.
  public static ADA_AgentSession load(String key) {
    if (key == null || !KEY_SHAPE.matcher(key).matches()) {
      throw notFound();
    }
    List<ADA_Action_Log__c> rows = [
      SELECT Result__c
      FROM ADA_Action_Log__c
      WHERE
        Session_Key__c = :key
        AND Step__c = 'Diagnose'
        AND OwnerId = :UserInfo.getUserId()
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw notFound();
    }
    return new ADA_AgentSession(key, restore(rows[0].Result__c));
  }

  private static ADA_Diagnosis restore(String stored) {
    try {
      State state = (State) JSON.deserialize(stored, State.class);
      ADA_Diagnosis diagnosis = new ADA_Diagnosis(
        ADA_ErrorType.valueOf(state.errorType),
        state.confidence
      );
      diagnosis.objectApiName = state.objectApiName;
      diagnosis.componentType = state.componentType;
      diagnosis.componentApiName = state.componentApiName;
      diagnosis.componentLabel = state.componentLabel;
      diagnosis.description = state.description;
      diagnosis.fieldApiNames = state.fieldApiNames == null
        ? new List<String>()
        : state.fieldApiNames;
      diagnosis.suggestedAction = ADA_SuggestedAction.valueOf(
        state.suggestedAction
      );
      return diagnosis;
    } catch (Exception damaged) {
      throw notFound();
    }
  }

  private static SessionException notFound() {
    return new SessionException('Session not found.');
  }

  private static String clip(String text, Integer max) {
    return text == null || text.length() <= max ? text : text.left(max);
  }
}
