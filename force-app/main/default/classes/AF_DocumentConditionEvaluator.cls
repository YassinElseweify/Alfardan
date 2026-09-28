/**
 * ALF-RS-12 (LFRDN-342) document-requirements engine. Ported from Albarari's
 * AB_DocumentConditionEvaluator (same expression grammar and matching logic, renamed AF_) so the
 * two orgs' document-checklist metadata stay interchangeable in shape.
 *
 * Evaluates AF_DocumentCondition__mdt.AF_Conditions__c against a queried SObject row.
 * Supports AND(...)/OR(...)/NOT(...), TEXT(field)='value', field='value', and field=TRUE/FALSE,
 * nestable via the function forms.
 */
public with sharing class AF_DocumentConditionEvaluator {
    private static final Pattern SIMPLE_EQ = Pattern.compile(
        '(?i)^\\s*([\\w.]+)\\s*=\\s*(?:\'([^\']*)\'|\"([^\"]*)\"|(TRUE|FALSE))\\s*$'
    );
    private static final Pattern TEXT_EQ = Pattern.compile(
        '(?i)^\\s*TEXT\\(\\s*([\\w.]+)\\s*\\)\\s*=\\s*(?:\'([^\']*)\'|\"([^\"]*)\")\\s*$'
    );

    /**
     * @param expression Condition text from custom metadata.
     * @param record Row loaded with fields from the dynamic field set (including relationships like RecordType.Name).
     * @return Whether the expression is satisfied.
     */
    public static Boolean evaluate(String expression, SObject record) {
        if (String.isBlank(expression) || record == null) {
            return false;
        }
        return evaluateInternal(expression.trim(), record);
    }

    private static Boolean evaluateInternal(String expr, SObject record) {
        if (String.isBlank(expr)) {
            return false;
        }
        if (expr.equalsIgnoreCase('true')) {
            return true;
        }
        if (expr.equalsIgnoreCase('false')) {
            return false;
        }

        if (startsWithFunction(expr, 'OR')) {
            List<String> args = parseFunctionArguments(expr, 'OR');
            if (args == null || args.isEmpty()) {
                return false;
            }
            for (String arg : args) {
                if (evaluateInternal(arg, record)) {
                    return true;
                }
            }
            return false;
        }

        if (startsWithFunction(expr, 'AND')) {
            List<String> args = parseFunctionArguments(expr, 'AND');
            if (args == null || args.isEmpty()) {
                return false;
            }
            for (String arg : args) {
                if (!evaluateInternal(arg, record)) {
                    return false;
                }
            }
            return true;
        }

        if (startsWithFunction(expr, 'NOT')) {
            List<String> args = parseFunctionArguments(expr, 'NOT');
            if (args == null || args.size() != 1) {
                return false;
            }
            return !evaluateInternal(args[0], record);
        }

        Matcher mText = TEXT_EQ.matcher(expr);
        if (mText.matches()) {
            String fieldPath = mText.group(1);
            String quoted = mText.group(2) != null ? mText.group(2) : mText.group(3);
            return compareStringField(record, fieldPath, quoted);
        }

        Matcher m = SIMPLE_EQ.matcher(expr);
        if (m.matches()) {
            String fieldPath = m.group(1);
            String strVal = m.group(2) != null ? m.group(2) : m.group(3);
            String boolLit = m.group(4);
            if (boolLit != null) {
                Object actual = getFieldValue(record, fieldPath);
                if (boolLit.equalsIgnoreCase('TRUE')) {
                    return actual == true;
                }
                return actual == false;
            }
            return compareStringField(record, fieldPath, strVal);
        }

        System.debug(LoggingLevel.WARN, 'AF_DocumentConditionEvaluator: unsupported expression - ' + expr);
        return false;
    }

    private static Boolean startsWithFunction(String expr, String functionName) {
        if (String.isBlank(expr)) {
            return false;
        }
        Integer openIdx = expr.indexOf('(');
        if (openIdx <= 0) {
            return false;
        }
        String fn = expr.substring(0, openIdx).trim();
        return fn.equalsIgnoreCase(functionName);
    }

    private static List<String> parseFunctionArguments(String expr, String functionName) {
        Integer openIdx = expr.indexOf('(');
        Integer closeIdx = expr.lastIndexOf(')');
        if (!startsWithFunction(expr, functionName) || closeIdx != expr.length() - 1 || closeIdx <= openIdx) {
            return null;
        }
        String argumentText = expr.substring(openIdx + 1, closeIdx);
        List<String> args = new List<String>();
        Integer segmentStart = 0;
        Integer depth = 0;
        Boolean inSingleQuote = false;
        Boolean inDoubleQuote = false;

        for (Integer i = 0; i < argumentText.length(); i++) {
            String ch = argumentText.substring(i, i + 1);
            if (ch == '\'' && !inDoubleQuote) {
                inSingleQuote = !inSingleQuote;
            } else if (ch == '"' && !inSingleQuote) {
                inDoubleQuote = !inDoubleQuote;
            } else if (!inSingleQuote && !inDoubleQuote) {
                if (ch == '(') {
                    depth++;
                } else if (ch == ')') {
                    depth--;
                    if (depth < 0) {
                        return null;
                    }
                } else if (ch == ',' && depth == 0) {
                    String arg = argumentText.substring(segmentStart, i).trim();
                    if (String.isBlank(arg)) {
                        return null;
                    }
                    args.add(arg);
                    segmentStart = i + 1;
                }
            }
        }

        if (inSingleQuote || inDoubleQuote || depth != 0) {
            return null;
        }

        String lastArg = argumentText.substring(segmentStart).trim();
        if (String.isBlank(lastArg)) {
            return null;
        }
        args.add(lastArg);
        return args;
    }

    private static Boolean compareStringField(SObject record, String fieldPath, String expected) {
        Object actual = getFieldValue(record, fieldPath);
        if (actual == null) {
            return expected == null || expected.length() == 0;
        }
        return String.valueOf(actual).equals(expected);
    }

    private static Object getFieldValue(SObject row, String path) {
        List<String> parts = path.split('\\.');
        SObject current = row;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            current = current.getSObject(parts[i]);
            if (current == null) {
                return null;
            }
        }
        return current.get(parts[parts.size() - 1]);
    }
}