public with sharing class ADA_Explanation {
  public String summary { get; private set; }
  public List<String> fixSteps { get; private set; }
  public String source { get; private set; }
  public ADA_SuggestedAction suggestedAction { get; set; }

  public ADA_Explanation(String summary, List<String> fixSteps, String source) {
    this.summary = summary == null ? '' : summary;
    this.fixSteps = fixSteps == null ? new List<String>() : fixSteps;
    this.source = String.isBlank(source) ? 'Template' : source;
    this.suggestedAction = ADA_SuggestedAction.EXPLAIN_ONLY;
  }
}
