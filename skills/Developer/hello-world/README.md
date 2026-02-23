# hello-world

A minimal example skill that prints "Hello, World!".

## Tag

`Developer`

## Description

This skill serves as a starting-point template for new skills.
It demonstrates the expected directory layout and README format.

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| name | string | No | Name to greet. Defaults to `"World"` if not provided. |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| message | string | The greeting message, e.g. `"Hello, World!"` |

## Example

**Input**
```json
{
  "name": "Alice"
}
```

**Output**
```json
{
  "message": "Hello, Alice!"
}
```
