# summarize

Summarizes a given text into a short paragraph.

## Tag

`OfficeWorker`

## Description

This skill takes a long piece of text and condenses it into a concise summary,
making it easier to quickly understand the key points.

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| text | string | Yes | The text to summarize. |
| max_sentences | integer | No | Maximum number of sentences in the summary. Defaults to `3`. |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| summary | string | A concise summary of the input text. |

## Example

**Input**
```json
{
  "text": "Artificial intelligence (AI) is intelligence demonstrated by machines, as opposed to the natural intelligence displayed by animals including humans. AI research has been defined as the field of study of intelligent agents, which refers to any system that perceives its environment and takes actions that maximize its chance of achieving its goals.",
  "max_sentences": 1
}
```

**Output**
```json
{
  "summary": "Artificial intelligence is machine-demonstrated intelligence focused on building systems that perceive their environment and act to achieve defined goals."
}
```
