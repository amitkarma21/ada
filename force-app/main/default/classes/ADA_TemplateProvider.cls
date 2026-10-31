public with sharing class ADA_TemplateProvider implements ADA_ILlmProvider {
  public ADA_Explanation explain(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  ) {
    ADA_ErrorType type = diagnosis == null
      ? ADA_ErrorType.UNKNOWN
      : diagnosis.errorType;
    String name = named(diagnosis);
    String detail = detail(diagnosis);
    if (type == ADA_ErrorType.REQUIRED_FIELD) {
      return result(
        'A required field is empty' +
          name +
          ', so Salesforce cannot save the record yet.' +
          detail,
        new List<String>{
          'Find the field named in the error message and enter a value.',
          'Save again.',
          'If you cannot see the field on your page, ask your admin to add it to your layout.'
        }
      );
    }
    if (type == ADA_ErrorType.VALIDATION_RULE) {
      return result(
        'A validation rule' +
          name +
          ' stopped the save because the record does not meet a condition your admin set.' +
          detail,
        new List<String>{
          'Read the error message: it says which value needs to change.',
          'Update that value so it meets the rule.',
          'Save again. If the rule looks wrong for your case, ask your admin to review it.'
        }
      );
    }
    if (type == ADA_ErrorType.DUPLICATE_RULE) {
      return result(
        'A duplicate rule' +
          name +
          ' found a record that looks the same as the one you are saving.' +
          detail,
        new List<String>{
          'Open the matching record that Salesforce suggests.',
          'Update that record instead of creating a new one, or check that your details are really different.',
          'Ask your admin if you believe this is not a duplicate.'
        }
      );
    }
    if (type == ADA_ErrorType.ACCESS) {
      return result(
        'You do not have permission to do this' +
          name +
          '. Access is controlled by your profile and permission sets.' +
          detail,
        new List<String>{
          'Check that you are working on a record or field you are allowed to change.',
          'Ask your admin which permission set gives you this access.',
          'Your admin can add the permission or share the record with you.'
        }
      );
    }
    if (type == ADA_ErrorType.FLOW) {
      return result(
        'An automation (flow)' +
          name +
          ' stopped the save and showed you its own message.' +
          detail,
        new List<String>{
          'Read the message from the flow: it says what is missing.',
          'Correct the record and save again.',
          'If the message does not make sense, ask your admin to check the flow.'
        }
      );
    }
    if (type == ADA_ErrorType.APEX) {
      return result(
        'Custom code' +
          name +
          ' stopped the save and showed you its own message.' +
          detail,
        new List<String>{
          'Read the message: it often says what needs to change.',
          'Correct the record and save again.',
          'If it keeps failing, ask your admin or developer to look at the code.'
        }
      );
    }
    return result(
      'ADA is not sure what blocked this save, so it will not guess.',
      new List<String>{
        'Copy the full error message.',
        'Send it to your admin with what you were trying to do.'
      }
    );
  }

  public String lastPayload() {
    return null;
  }

  private static ADA_Explanation result(String summary, List<String> steps) {
    return new ADA_Explanation(summary, steps, 'Template');
  }

  private static String named(ADA_Diagnosis diagnosis) {
    if (diagnosis == null) {
      return '';
    }
    String label = String.isBlank(diagnosis.componentLabel)
      ? diagnosis.componentApiName
      : diagnosis.componentLabel;
    return String.isBlank(label) ? '' : ' (' + label + ')';
  }

  private static String detail(ADA_Diagnosis diagnosis) {
    if (diagnosis == null || String.isBlank(diagnosis.description)) {
      return '';
    }
    return ' ' + diagnosis.description.abbreviate(300);
  }
}
