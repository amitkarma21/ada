public with sharing class ADA_PayloadBuilder {
  public static final Integer MAX_QUESTION = 500;
  public static final Integer MAX_DESCRIPTION = 500;
  public static final Integer MAX_FORMULA = 1000;
  public static final Integer MAX_MESSAGE = 500;
  public static final Integer MAX_LABEL = 120;
  public static final Integer MAX_LIST = 20;
  public static final Integer MAX_NOTES = 2000;

  public class Extras {
    public String objectLabel;
    public String conditionFormulaMasked;
    public String ruleMessage;
    public String flowRunsWhen;
    public List<String> fieldLabels = new List<String>();
    public Map<String, String> fieldLabelsByApiName = new Map<String, String>();
    public List<String> missingPermissionLabels = new List<String>();
    public String userQuestion;
    public String locale;
  }

  // The LLM request body (ARCHITECTURE section 4). Every field the model may see is here;
  // adding a field means changing this class and the contract together.
  public class LlmBody {
    public String errorType;
    public String objectApiName;
    public String objectLabel;
    public String componentType;
    public String componentApiName;
    public String componentLabel;
    public String componentDescription;
    public String conditionFormulaMasked;
    public String ruleMessage;
    public String flowRunsWhen;
    public List<String> fieldLabels;
    public List<String> missingPermissionLabels;
    public String userQuestion;
    public String locale;
  }

  // The work item preview (ARCHITECTURE section 4, Azure DevOps). Metadata and the
  // user's own notes after the PII gate; no error text and no record values.
  public class WorkItemBody {
    public String title;
    public String description;
    public String tags;
  }

  public static LlmBody forLlm(ADA_Diagnosis diagnosis, Extras extras) {
    Extras input = extras == null ? new Extras() : extras;
    LlmBody body = new LlmBody();
    body.errorType = diagnosis.errorType.name();
    body.objectApiName = diagnosis.objectApiName;
    body.objectLabel = clip(patternsOnly(input.objectLabel), MAX_LABEL);
    body.componentType = diagnosis.componentType;
    body.componentApiName = diagnosis.componentApiName;
    body.componentLabel = clip(
      ADA_PiiGate.scrub(diagnosis.componentLabel).text,
      MAX_LABEL
    );
    body.componentDescription = clip(
      ADA_PiiGate.scrub(diagnosis.description).text,
      MAX_DESCRIPTION
    );
    body.conditionFormulaMasked = clip(
      ADA_FormulaMasker.mask(input.conditionFormulaMasked),
      MAX_FORMULA
    );
    body.ruleMessage = clip(
      ADA_PiiGate.scrub(input.ruleMessage).text,
      MAX_MESSAGE
    );
    body.flowRunsWhen = clip(patternsOnly(input.flowRunsWhen), MAX_LABEL * 2);
    body.fieldLabels = labels(input.fieldLabels);
    body.missingPermissionLabels = labels(input.missingPermissionLabels);
    body.userQuestion = clip(
      ADA_PiiGate.scrub(input.userQuestion).text,
      MAX_QUESTION
    );
    body.locale = String.isBlank(input.locale)
      ? UserInfo.getLocale()
      : input.locale;
    return body;
  }

  public static String toJson(LlmBody body) {
    return JSON.serialize(body, true);
  }

  public static WorkItemBody forWorkItem(
    ADA_Diagnosis diagnosis,
    String sessionKey,
    String userNotes
  ) {
    WorkItemBody body = new WorkItemBody();
    String type = diagnosis.errorType.name();
    String component = diagnosis.componentApiName;
    body.title = 'ADA: ' + type;
    if (String.isNotBlank(diagnosis.objectApiName)) {
      body.title += ' on ' + diagnosis.objectApiName;
    }
    if (String.isNotBlank(component)) {
      body.title += ' (' + component + ')';
    }
    List<String> lines = new List<String>{ 'Error type: ' + type };
    if (String.isNotBlank(diagnosis.objectApiName)) {
      lines.add('Object: ' + diagnosis.objectApiName);
    }
    if (String.isNotBlank(component)) {
      String label = String.isBlank(diagnosis.componentLabel)
        ? component
        : clip(ADA_PiiGate.scrub(diagnosis.componentLabel).text, MAX_LABEL);
      lines.add('Component: ' + label + ' [' + diagnosis.componentType + ']');
    }
    lines.add('Confidence: ' + diagnosis.confidence);
    lines.add('Session: ' + sessionKey);
    String notes = clip(ADA_PiiGate.scrub(userNotes).text, MAX_NOTES);
    if (String.isNotBlank(notes)) {
      lines.add('');
      lines.add('User notes:');
      lines.add(notes);
    }
    body.description = String.join(lines, '\n');
    body.tags = String.isBlank(component)
      ? 'ADA'
      : 'ADA; ADA-rule:' + component;
    return body;
  }

  public static String toJson(WorkItemBody body) {
    return JSON.serialize(body, true);
  }

  private static List<String> labels(List<String> source) {
    List<String> kept = new List<String>();
    if (source == null) {
      return kept;
    }
    for (String label : source) {
      if (String.isBlank(label)) {
        continue;
      }
      if (kept.size() == MAX_LIST) {
        break;
      }
      kept.add(clip(patternsOnly(label), MAX_LABEL));
    }
    return kept;
  }

  private static String patternsOnly(String text) {
    return ADA_PiiGate.scrubPatterns(text).text;
  }

  private static String clip(String text, Integer max) {
    return text == null || text.length() <= max ? text : text.left(max);
  }
}
