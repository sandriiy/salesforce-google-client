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
public without sharing class GoogleCloudChatterPollChoicesCommand {
  private final Id feedItemId;
  private final List<String> choiceValues;

  public GoogleCloudChatterPollChoicesCommand(
    Id feedItemId,
    List<String> choiceValues
  ) {
    this.feedItemId = feedItemId;
    this.choiceValues = choiceValues == null
      ? new List<String>()
      : new List<String>(choiceValues);
  }

  public void execute() {
    if (feedItemId == null) {
      throw new AuraHandledException(
        'Poll publishing is unavailable because the feed post could not be resolved.'
      );
    }

    if (choiceValues.size() < 2) {
      throw new AuraHandledException(
        'A poll requires at least two non-empty choices.'
      );
    }

    Schema.SObjectType pollChoiceType = Schema.getGlobalDescribe()
      .get('FeedPollChoice');
    if (pollChoiceType == null) {
      throw new AuraHandledException(
        'Poll choices are unavailable in this org configuration.'
      );
    }

    Schema.DescribeSObjectResult pollChoiceDescribe = pollChoiceType.getDescribe();
    if (!pollChoiceDescribe.isCreateable()) {
      throw new AuraHandledException(
        'Poll publishing is unavailable in this org.'
      );
    }

    Map<String, Schema.SObjectField> fields = pollChoiceDescribe.fields.getMap();

    String parentFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'FeedItemId', 'ParentId' }
    );
    String choiceFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'ChoiceBody', 'ChoiceText', 'Name', 'Text' }
    );
    String positionFieldName = resolveFirstExistingField(
      fields,
      new List<String>{ 'Position', 'SortOrder' }
    );

    if (String.isBlank(parentFieldName) || String.isBlank(choiceFieldName)) {
      throw new AuraHandledException(
        'Unable to resolve poll choice fields in this org.'
      );
    }

    List<SObject> recordsToInsert = new List<SObject>();
    Integer position = 1;

    for (String choice : choiceValues) {
      SObject pollChoiceRecord = pollChoiceType.newSObject();
      pollChoiceRecord.put(parentFieldName, feedItemId);
      pollChoiceRecord.put(choiceFieldName, choice);

      if (!String.isBlank(positionFieldName)) {
        pollChoiceRecord.put(positionFieldName, position);
      }

      recordsToInsert.add(pollChoiceRecord);
      position++;
    }

    try {
      Database.insert(recordsToInsert, AccessLevel.USER_MODE);
    } catch (DmlException ex) {
      throw new AuraHandledException(
        'Unable to save poll choices. Please verify your permissions and try again.'
      );
    }
  }

  private static String resolveFirstExistingField(
    Map<String, Schema.SObjectField> fields,
    List<String> candidates
  ) {
    for (String candidate : candidates) {
      if (fields.containsKey(candidate)) {
        return candidate;
      }
    }

    return null;
  }
}
