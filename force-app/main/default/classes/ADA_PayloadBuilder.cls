public with sharing class ADA_PayloadBuilder {
  public static final Integer MAX_QUESTION = 500;
  public static final Integer MAX_DESCRIPTION = 500;
  public static final Integer MAX_FORMULA = 1000;
  public static final Integer MAX_LABEL = 120;
  public static final Integer MAX_LIST = 20;

  public class Extras {
    public String objectLabel;
    public String conditionFormulaMasked;
    public List<String> fieldLabels = new List<String>();
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
    public List<String> fieldLabels;
    public List<String> missingPermissionLabels;
    public String userQuestion;
    public String locale;
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
