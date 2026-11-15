public with sharing class ADA_TemplateProvider implements ADA_ILlmProvider {
  private static final Integer MAX_SUMMARY = 1200;
  private static final Integer MAX_MESSAGE = 300;
  private static final Integer MAX_FIXES = 3;
  private static final Integer MAX_FIELDS = 8;

  public ADA_Explanation explain(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  ) {
    if (extras != null && extras.followUp == true) {
      return result(
        'I cannot answer follow-up questions without the AI model, and it is not available right now. Your admin can answer this one.',
        new List<String>{
          'Send your question to your admin, together with the error message you saw.',
          'Read the steps above again in case they already cover it.'
        }
      );
    }
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
      return validationRule(diagnosis, extras);
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
      return flow(diagnosis, extras);
    }
    if (type == ADA_ErrorType.APEX) {
      return result(
        'Custom code' +
          name +
          ' stopped the save and showed you its own message.' +
          quoted(extras) +
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

  private static ADA_Explanation validationRule(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  ) {
    String message = messageOf(extras);
    ADA_FormulaReader.Reading reading = extras == null
      ? null
      : ADA_FormulaReader.read(
          extras.conditionFormulaMasked,
          extras.fieldLabelsByApiName
        );
    List<String> fields = fieldNames(extras);
    String summary =
      'A validation rule' +
      named(diagnosis) +
      ' stopped the save';
    summary += message == null &&
      reading == null
      ? ' because the record does not meet a condition your admin set.'
      : '.';
    if (message != null) {
      summary += ' Its message says: "' + withStop(message) + '"';
    }
    if (reading != null) {
      summary += ' ' + describe(reading);
    }
    summary += detail(diagnosis);
    List<String> steps = new List<String>();
    if (reading != null) {
      for (String fix : reading.fixes) {
        if (steps.size() < MAX_FIXES) {
          steps.add(fix);
        }
      }
    }
    if (steps.isEmpty() && !fields.isEmpty()) {
      steps.add(
        'Check the fields the rule looks at: ' + String.join(fields, ', ') + '.'
      );
      steps.add(
        'Change the value that does not meet the rule, as the error message describes.'
      );
    }
    if (steps.isEmpty()) {
      steps.add('Read the error message: it says which value needs to change.');
      steps.add('Update that value so it meets the rule.');
    }
    steps.add('Save again.');
    steps.add(
      'If the rule looks wrong for your case, ask your admin to review it.'
    );
    return result(summary.abbreviate(MAX_SUMMARY), steps);
  }

  private static ADA_Explanation flow(
    ADA_Diagnosis diagnosis,
    ADA_PayloadBuilder.Extras extras
  ) {
    Boolean fault = diagnosis.runtimeFault == true;
    String summary = 'An automation (flow)' + named(diagnosis);
    if (fault) {
      summary += ' hit an error while it was running, so the save did not go through.';
    } else {
      summary +=
        ' stopped the save and showed you its own message.' + quoted(extras);
    }
    if (extras != null && String.isNotBlank(extras.flowRunsWhen)) {
      summary += ' This flow runs ' + extras.flowRunsWhen + '.';
    }
    ADA_FormulaReader.Reading entry = extras == null
      ? null
      : ADA_FormulaReader.read(
          extras.conditionFormulaMasked,
          extras.fieldLabelsByApiName
        );
    if (entry != null) {
      summary += ' ' + entryRule(entry);
    }
    summary += detail(diagnosis);
    List<String> steps = fault
      ? new List<String>{
          'Note what you were doing and which record you were saving.',
          'Try again in a moment, in case it was a one-off problem.',
          'If it fails again, send a report to your admin team so they can check the flow.'
        }
      : new List<String>{
          'Read the message from the flow: it says what is missing.',
          'Correct the record and save again.',
          'If the message does not make sense, ask your admin to check the flow.'
        };
    return result(summary.abbreviate(MAX_SUMMARY), steps);
  }

  private static String entryRule(ADA_FormulaReader.Reading reading) {
    String conditions = String.join(reading.conditions, '; ');
    if (reading.mode == ADA_FormulaReader.MODE_ALL) {
      return 'It only acts on a record when all of these are true: ' +
        conditions +
        '.';
    }
    if (reading.mode == ADA_FormulaReader.MODE_ANY) {
      return 'It only acts on a record when any one of these is true: ' +
        conditions +
        '.';
    }
    return 'It only acts on a record when ' + conditions + '.';
  }

  private static String describe(ADA_FormulaReader.Reading reading) {
    String conditions = String.join(reading.conditions, '; ');
    if (reading.mode == ADA_FormulaReader.MODE_ALL) {
      return 'The rule blocks the save when all of these are true: ' +
        conditions +
        '. The save will go through as soon as any one of them is no longer true.';
    }
    if (reading.mode == ADA_FormulaReader.MODE_ANY) {
      return 'The rule blocks the save when any one of these is true: ' +
        conditions +
        '. None of them can be true when you save.';
    }
    return 'The rule blocks the save when ' + conditions + '.';
  }

  private static String messageOf(ADA_PayloadBuilder.Extras extras) {
    if (extras == null || String.isBlank(extras.ruleMessage)) {
      return null;
    }
    return extras.ruleMessage.trim().abbreviate(MAX_MESSAGE);
  }

  private static String quoted(ADA_PayloadBuilder.Extras extras) {
    String message = messageOf(extras);
    return message == null ? '' : ' It said: "' + withStop(message) + '"';
  }

  private static String withStop(String message) {
    return message.endsWith('.') ||
      message.endsWith('!') ||
      message.endsWith('?')
      ? message
      : message + '.';
  }

  private static List<String> fieldNames(ADA_PayloadBuilder.Extras extras) {
    List<String> names = new List<String>();
    if (extras == null) {
      return names;
    }
    List<String> source = extras.fieldLabels.isEmpty() &&
      extras.fieldLabelsByApiName != null
      ? extras.fieldLabelsByApiName.values()
      : extras.fieldLabels;
    for (String name : source) {
      if (String.isNotBlank(name) && names.size() < MAX_FIELDS) {
        names.add(name);
      }
    }
    return names;
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
