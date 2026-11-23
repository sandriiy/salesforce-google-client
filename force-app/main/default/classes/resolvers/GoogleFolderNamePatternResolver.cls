/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * The folder name pattern language: a Salesforce formula that returns text, compiled and evaluated in Apex.
 * Salesforce writes every value the same way whoever runs it (TEXT of a date and time is in GMT, a picklist
 * is its stored value) and refuses $User, so a name never depends on who uploads. Reads no records; the
 * caller queries the fields toQueriedFields() returns, related ones included.
 */
public with sharing class GoogleFolderNamePatternResolver {
	public class GoogleFolderNamePatternResolverException extends Exception {}

	/**
	 * The longest folder name a pattern produces. Longer results are cut, so a long text field cannot make a
	 * name that desktop sync tools refuse.
	 */
	public static final Integer MAX_FOLDER_NAME_LENGTH = 255;

	private static final String BLANK_PATTERN_MESSAGE = 'Enter a formula that returns text.';
	private static final String SELF_CHANGING_FUNCTION_WARNING = 'TODAY(), NOW() and TIMENOW() change by themselves, so folders would be renamed whenever a file is added.';
	private static final String ALWAYS_CHANGING_FIELD_WARNING = '{0} changes every time the record is saved, so folders would be renamed whenever a file is added.';
	private static final Pattern SELF_CHANGING_FUNCTION = Pattern.compile('(?i)\\b(TODAY|NOW|TIMENOW)\\s*\\(');
	private static final Set<String> ALWAYS_CHANGING_FIELDS = new Set<String>{
		'lastmodifieddate', 'systemmodstamp', 'lastmodifiedbyid', 'lastactivitydate', 'lastvieweddate', 'lastreferenceddate'
	};
	private static final String FIELD_PATH_SEPARATOR = '.';
	private static final String TYPE_QUALIFIER = ':';
	private static final String TYPE_QUALIFIER_PATTERN = ':[^.]*';
	private static final String ID_FIELD = 'id';

	private static Map<String, FormulaEval.FormulaInstance> compiledFormulasByKey = new Map<String, FormulaEval.FormulaInstance>();

	/**
	 * Compiles a pattern against an object, once per object and pattern in a transaction.
	 *
	 * @param objectType The object whose records the pattern names.
	 * @param pattern The formula, which must return text.
	 * @return The compiled formula.
	 */
	public FormulaEval.FormulaInstance compile(Schema.SObjectType objectType, String pattern) {
		if (objectType == null || String.isBlank(pattern)) {
			throw new GoogleFolderNamePatternResolverException(BLANK_PATTERN_MESSAGE);
		}

		String formulaKey = String.valueOf(objectType) + ':' + pattern;
		if (compiledFormulasByKey.containsKey(formulaKey)) {
			return compiledFormulasByKey.get(formulaKey);
		}

		FormulaEval.FormulaInstance formula = Formula.builder()
			.withFormula(pattern)
			.withType(objectType)
			.withReturnType(FormulaEval.FormulaReturnType.STRING)
			.build();

		compiledFormulasByKey.put(formulaKey, formula);
		return formula;
	}

	/**
	 * Says why a pattern cannot be used, in Salesforce's own words: a syntax error, an unknown field, a value
	 * that depends on the user, or a result that is not text.
	 *
	 * @param objectType The object whose records the pattern names.
	 * @param pattern The formula to check.
	 * @return The problems, empty when the pattern can be used.
	 */
	public List<String> findProblems(Schema.SObjectType objectType, String pattern) {
		List<String> problems = new List<String>();
		if (objectType == null || String.isBlank(pattern)) {
			problems.add(BLANK_PATTERN_MESSAGE);
			return problems;
		}

		try {
			compile(objectType, pattern);
		} catch (Exception ex) {
			problems.add(ex.getMessage());
		}

		return problems;
	}

	/**
	 * Says why a usable pattern would rename folders by itself, which the administrator has to confirm before
	 * saving it: TODAY(), NOW() or TIMENOW(), or a field that changes on every save, on the record or a related
	 * one.
	 *
	 * @param pattern The formula to check.
	 * @param referencedFields The fields the compiled formula references.
	 * @return The warnings, empty when the name changes only when the record does.
	 */
	public List<String> findWarnings(String pattern, Set<String> referencedFields) {
		List<String> warnings = new List<String>();
		if (String.isNotBlank(pattern) && SELF_CHANGING_FUNCTION.matcher(pattern).find()) {
			warnings.add(SELF_CHANGING_FUNCTION_WARNING);
		}

		if (referencedFields == null) return warnings;

		for (String fieldPath : referencedFields) {
			if (String.isBlank(fieldPath)) continue;

			String fieldName = fieldPath.contains(FIELD_PATH_SEPARATOR) ? fieldPath.substringAfterLast(FIELD_PATH_SEPARATOR) : fieldPath;
			if (ALWAYS_CHANGING_FIELDS.contains(fieldName.toLowerCase())) {
				warnings.add(String.format(ALWAYS_CHANGING_FIELD_WARNING, new List<Object>{ fieldPath }));
			}
		}

		return warnings;
	}

	/**
	 * Turns the fields a compiled pattern references into the fields to query, without the Id and repeats.
	 * A formula names the type of an owner that can also be a queue (Owner:User.FirstName) and a query
	 * cannot, so that step is queried as Owner.FirstName, which the formula still reads.
	 *
	 * @param referencedFields The fields the compiled formula references.
	 * @return The fields to select on top of the Id.
	 */
	public List<String> toQueriedFields(Set<String> referencedFields) {
		List<String> queriedFields = new List<String>();
		Set<String> seenFields = new Set<String>{ ID_FIELD };
		if (referencedFields == null) return queriedFields;

		for (String fieldPath : referencedFields) {
			if (String.isBlank(fieldPath)) continue;

			String queriedField = fieldPath.replaceAll(TYPE_QUALIFIER_PATTERN, '');
			if (seenFields.contains(queriedField.toLowerCase())) continue;

			seenFields.add(queriedField.toLowerCase());
			queriedFields.add(queriedField);
		}

		return queriedFields;
	}

	/**
	 * Names one record. Line breaks and runs of spaces become one space, and the result is cut to the longest
	 * folder name. A blank result, or one where every referenced field is blank, is blank, so literal text
	 * alone never names every such record's folder the same.
	 *
	 * @param formula The compiled pattern.
	 * @param record The record, holding every field the formula references.
	 * @return The folder name, or null when the caller should use the usual name.
	 */
	public String render(FormulaEval.FormulaInstance formula, SObject record) {
		if (formula == null || record == null) return null;
		if (!hasAnyReferencedValue(formula.getReferencedFields(), record)) return null;

		Object result = formula.evaluate(record);
		String folderName = result == null ? null : String.valueOf(result).normalizeSpace();
		if (String.isBlank(folderName)) return null;

		return folderName.length() > MAX_FOLDER_NAME_LENGTH
			? folderName.left(MAX_FOLDER_NAME_LENGTH).trim()
			: folderName;
	}

	private Boolean hasAnyReferencedValue(Set<String> referencedFields, SObject record) {
		if (referencedFields == null || referencedFields.isEmpty()) return true;

		for (String fieldPath : referencedFields) {
			Object value = readFieldPath(record, fieldPath);
			if (value instanceof String ? String.isNotBlank((String) value) : value != null) return true;
		}

		return false;
	}

	private Object readFieldPath(SObject record, String fieldPath) {
		if (record == null || String.isBlank(fieldPath)) return null;

		try {
			List<String> pathParts = fieldPath.split('\\.');
			SObject currentRecord = record;
			for (Integer partIndex = 0; partIndex < pathParts.size() - 1; partIndex++) {
				currentRecord = currentRecord.getSObject(pathParts[partIndex].substringBefore(TYPE_QUALIFIER));
				if (currentRecord == null) return null;
			}

			return currentRecord.get(pathParts[pathParts.size() - 1]);
		} catch (Exception ex) {
			return null;
		}
	}
}
